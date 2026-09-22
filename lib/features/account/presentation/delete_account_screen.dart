import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/account/data/account_deletion_service.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:share_plus/share_plus.dart';

enum _Phase { explain, running, done, failed }

/// Étapes affichées pendant la suppression (toutes réelles).
enum _Step { anilist, data, account }

enum _StepState { pending, running, done }

/// Suppression du compte NextArc : explication, confirmation forte, étapes
/// visibles, écran de fin qui laisse l'app utilisable en invité.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _service = AccountDeletionService();

  _Phase _phase = _Phase.explain;
  late final Map<_Step, _StepState> _steps;

  /// Identité mémorisée avant la suppression (affichée ensuite).
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _user = ref.read(authProvider).valueOrNull?.user;
    _steps = {
      if (_user?.hasAnilist ?? false) _Step.anilist: _StepState.pending,
      _Step.data: _StepState.pending,
      _Step.account: _StepState.pending,
    };
  }

  Future<void> _export() async {
    final entries = ref.read(firestoreWatchlistProvider).valueOrNull ?? [];
    await Share.share(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
      subject: 'NextArc — Ma watchlist',
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(user: _user),
    );
    if (confirmed == true) await _run();
  }

  /// Enchaîne les étapes non encore faites (reprise possible après échec).
  Future<void> _run() async {
    setState(() => _phase = _Phase.running);
    try {
      for (final step in _steps.keys.toList()) {
        if (_steps[step] == _StepState.done) continue;
        setState(() => _steps[step] = _StepState.running);
        switch (step) {
          case _Step.anilist:
            // Retire seulement le jeton local : rien n'est écrit sur AniList
            await ref.read(authRepositoryProvider).logout();
          case _Step.data:
            await _service.run(DeletionServerStep.data);
          case _Step.account:
            // Apple exige de révoquer « Se connecter avec Apple » d'abord
            await ref.read(firebaseAuthServiceProvider).revokeAppleIfLinked();
            await _service.run(DeletionServerStep.account);
            // Compte supprimé côté serveur : on quitte la session localement
            await ref.read(authProvider.notifier).logout();
        }
        if (mounted) setState(() => _steps[step] = _StepState.done);
      }
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _phase = _Phase.done);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _steps.updateAll(
            (_, s) => s == _StepState.running ? _StepState.pending : s);
        _phase = _Phase.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Ni retour pendant la suppression, ni retour vers un compte supprimé
      canPop: _phase == _Phase.explain || _phase == _Phase.failed,
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: AppMotion.transition,
            child: switch (_phase) {
              _Phase.explain => _ExplainView(
                  key: const ValueKey('explain'),
                  user: _user,
                  onExport: _export,
                  onContinue: _confirmAndDelete,
                ),
              _Phase.running => _RunningView(
                  key: const ValueKey('running'),
                  steps: _steps,
                ),
              _Phase.done => _DoneView(
                  key: const ValueKey('done'),
                  anilistName: _user?.hasAnilist == true
                      ? (_user?.anilistName ?? _user?.name)
                      : null,
                ),
              _Phase.failed => _FailedView(
                  key: const ValueKey('failed'),
                  onRetry: _run,
                  onCancel: () => context.pop(),
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ── Explication ───────────────────────────────────────────────────────────────

class _ExplainView extends ConsumerWidget {
  const _ExplainView({
    super.key,
    required this.user,
    required this.onExport,
    required this.onContinue,
  });

  final UserModel? user;
  final VoidCallback onExport;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = ref.watch(statsProvider).valueOrNull;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());
    final anilistName =
        user?.hasAnilist == true ? (user?.anilistName ?? user?.name) : null;

    final removed = [
      'delete_removed_account'.tr(),
      'delete_removed_list'.tr(),
      'delete_removed_notes'.tr(),
      if (stats == null)
        'delete_removed_stats_generic'.tr()
      else
        'delete_removed_stats'.tr(namedArgs: {
          'episodes': numbers.format(stats.episodesWatched),
          'hours': numbers.format(stats.title.totalHours),
          'completed': numbers.format(stats.title.totalCompleted),
        }),
      if (stats != null)
        'delete_removed_title'.tr(namedArgs: {'title': stats.title.label}),
      'delete_removed_profile'.tr(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: 'delete_title'.tr()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.md),
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'delete_intro_prefix'.tr()),
                  TextSpan(
                    text: 'delete_intro_strong'.tr(),
                    style: TextStyle(
                        color: c.text1, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'delete_intro_suffix'.tr()),
                ]),
                style: text.bodyMedium
                    ?.copyWith(color: c.text2, fontSize: 12.5, height: 1.65),
              ),
              const SizedBox(height: AppSpacing.md),
              _BulletCard(
                label: 'delete_removed'.tr(),
                labelColor: isDark
                    ? const Color(0xFFB96A78)
                    : c.statusDroppedText,
                tint: c.favourite,
                icon: Icons.close_rounded,
                iconColor: c.statusDroppedText,
                items: removed,
              ),
              if (anilistName != null) ...[
                const SizedBox(height: AppSpacing.md),
                _BulletCard(
                  label: 'delete_kept'.tr(),
                  labelColor: isDark
                      ? const Color(0xFF4E9D7C)
                      : c.statusCurrent,
                  tint: c.statusCurrent,
                  icon: Icons.check_rounded,
                  iconColor: c.statusCurrent,
                  items: [
                    'delete_kept_anilist'.tr(),
                    'delete_kept_unlink'.tr(),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Material(
                color: c.surface1,
                borderRadius: BorderRadius.circular(AppRadius.card),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onExport,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _IconBox(icon: Icons.upload_rounded, color: c.accentText),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('delete_export'.tr(),
                                  style: text.titleSmall?.copyWith(
                                      color: c.text1, fontSize: 12.5)),
                              const SizedBox(height: 2),
                              Text('delete_export_sub'.tr(),
                                  style: text.bodySmall?.copyWith(
                                      color: c.text2, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: c.text3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'dialog_cancel'.tr(),
                    variant: AppButtonVariant.secondary,
                    expand: true,
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: AppButton(
                    label: 'delete_continue'.tr(),
                    variant: AppButtonVariant.destructive,
                    expand: true,
                    onPressed: onContinue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 12),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontSize: 19, color: c.text1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloc « supprimé / conservé » : sur-titre + carte teintée à puces.
class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.label,
    required this.labelColor,
    required this.tint,
    required this.icon,
    required this.iconColor,
    required this.items,
  });

  final String label;
  final Color labelColor;
  final Color tint;
  final IconData icon;
  final Color iconColor;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(), style: AppTypography.overline(labelColor)),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: tint.withValues(alpha: 0.24)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 15, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.text1,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

// ── Confirmation « taper SUPPRIMER » ──────────────────────────────────────────

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({required this.user});

  final UserModel? user;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final word = 'delete_confirm_word'.tr();
    final matches = deletionConfirmationMatches(_controller.text, word);
    final media = MediaQuery.of(context);
    final user = widget.user;

    return Container(
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: c.favourite.withValues(alpha: 0.3)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(18, 12, 18,
          media.viewInsets.bottom + media.viewPadding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.text3.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.favourite.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 20, color: c.favourite),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('delete_confirm_title'.tr(),
                        style: text.headlineSmall
                            ?.copyWith(fontSize: 17, color: c.text1)),
                    const SizedBox(height: 3),
                    Text('delete_confirm_sub'.tr(),
                        style: text.bodySmall?.copyWith(color: c.text2)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'delete_confirm_prefix'.tr()),
              TextSpan(
                text: word,
                style: AppTypography.overline(c.statusDroppedText)
                    .copyWith(fontSize: 12.5, letterSpacing: 0.5),
              ),
              TextSpan(text: 'delete_confirm_suffix'.tr()),
            ]),
            style: text.bodyMedium?.copyWith(color: c.text2, height: 1.6),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: AppTypography.overline(c.text1)
                .copyWith(fontSize: 15, letterSpacing: 1.5),
            decoration: InputDecoration(
              counterText: '',
              suffixText:
                  '${_controller.text.trim().length}/${word.length}',
              suffixStyle: AppTypography.overline(c.text3)
                  .copyWith(fontSize: 10.5, letterSpacing: 0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                borderSide: BorderSide(
                    color: matches ? c.favourite : c.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.cover),
                borderSide: BorderSide(
                    color: matches ? c.favourite : c.accentText, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            matches
                ? 'delete_confirm_ok'.tr()
                : 'delete_confirm_hint'.tr(),
            style: text.bodySmall?.copyWith(color: c.text3, fontSize: 10.5),
          ),
          if (user != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface2.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.cover),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: c.accentGradient,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.displayName.characters.first.toUpperCase(),
                      style: text.titleSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName,
                            style: text.titleSmall?.copyWith(
                                color: c.text1, fontSize: 12.5)),
                        if (user.email != null)
                          Text(user.email!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                  color: c.text2, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'dialog_cancel'.tr(),
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: AppButton(
                  label: 'delete_confirm_button'.tr(),
                  variant: AppButtonVariant.danger,
                  expand: true,
                  onPressed:
                      matches ? () => Navigator.of(context).pop(true) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── En cours ──────────────────────────────────────────────────────────────────

class _RunningView extends StatelessWidget {
  const _RunningView({super.key, required this.steps});

  final Map<_Step, _StepState> steps;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    String label(_Step step) => switch (step) {
          _Step.anilist => 'delete_step_anilist'.tr(),
          _Step.data => 'delete_step_data'.tr(),
          _Step.account => 'delete_step_account'.tr(),
        };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: c.accentText,
                backgroundColor: c.surface2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('delete_running_title'.tr(),
                textAlign: TextAlign.center,
                style: text.headlineSmall
                    ?.copyWith(fontSize: 16, color: c.text1)),
            const SizedBox(height: AppSpacing.xs),
            Text('delete_running_body'.tr(),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: c.text2, height: 1.55)),
            const SizedBox(height: AppSpacing.lg),
            for (final entry in steps.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: switch (entry.value) {
                        _StepState.done => Icon(Icons.check_rounded,
                            size: 16, color: c.statusCurrent),
                        _StepState.running => SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: c.accentText),
                          ),
                        _StepState.pending => Icon(Icons.circle,
                            size: 6, color: c.text3),
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label(entry.key),
                        style: text.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: entry.value == _StepState.running
                              ? c.text1
                              : c.text2,
                          fontWeight: entry.value == _StepState.running
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Terminé / échec ───────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({super.key, required this.anilistName});

  final String? anilistName;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: c.statusCurrent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 28, color: c.statusCurrent),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('delete_done_title'.tr(),
                style: text.headlineSmall
                    ?.copyWith(fontSize: 17, color: c.text1)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'delete_done_body'.tr() +
                  (anilistName == null
                      ? ''
                      : 'delete_done_anilist'
                          .tr(namedArgs: {'name': anilistName!})),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.text2, height: 1.6),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'delete_done_guest'.tr(),
              expand: true,
              onPressed: () => context.go(AppRoutes.discover),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'delete_done_new'.tr(),
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed: () => context.go(AppRoutes.profile),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('delete_done_thanks'.tr(),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: c.text3, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    super.key,
    required this.onRetry,
    required this.onCancel,
  });

  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.favourite),
            const SizedBox(height: AppSpacing.md),
            Text('delete_failed_title'.tr(),
                textAlign: TextAlign.center,
                style: text.headlineSmall
                    ?.copyWith(fontSize: 17, color: c.text1)),
            const SizedBox(height: AppSpacing.xs),
            Text('delete_failed_body'.tr(),
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.text2, height: 1.6)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'delete_retry'.tr(),
              icon: Icons.refresh_rounded,
              expand: true,
              onPressed: onRetry,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'dialog_cancel'.tr(),
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
