import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/constants/app_version.dart';
import 'package:nextarc/core/providers/theme_provider.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_backup.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:share_plus/share_plus.dart';

/// Écran Paramètres — accessible depuis le profil.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final repo = ref.read(guestWatchlistRepositoryProvider);
      final jsonStr = await repo.exportJson();
      await Share.share(
        jsonStr,
        subject: 'NextArc — Ma watchlist',
      );
      await recordGuestExport();
      ref.invalidate(lastGuestExportProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('settings_export_error'
                  .tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final jsonStr = utf8.decode(bytes);
      await ref.read(guestWatchlistRepositoryProvider).importJson(jsonStr);
      ref.invalidate(guestWatchlistProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_import_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('settings_import_error'
                  .tr(namedArgs: {'error': e.toString()}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final currentMode = ref.watch(themeProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // L'export/import ne concerne que la liste locale : un compte NextArc
    // est sauvegardé dans Firestore.
    final isGuest = ref
            .watch(authProvider)
            .whenOrNull(data: (a) => !a.isAuthenticated) ??
        true;

    final themeHint = switch (currentMode) {
      ThemeMode.system => 'settings_theme_system_subtitle',
      ThemeMode.dark => 'settings_theme_dark_subtitle',
      ThemeMode.light => 'settings_theme_light_subtitle',
    };

    final backup = backupAge(
      ref.watch(lastGuestExportProvider).valueOrNull,
      DateTime.now(),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen, 0),
              child: Row(
                children: [
                  _RoundBackButton(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.profile),
                  ),
                  const SizedBox(width: 6),
                  Text('settings_title'.tr(),
                      style: text.headlineSmall
                          ?.copyWith(fontSize: 19, color: c.text1)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md,
                    AppSpacing.screen, AppSpacing.xl + bottomInset),
                children: [
                  // ── Apparence ─────────────────────────────────────────────
                  _Section(
                    label: 'settings_section_appearance'.tr(),
                    children: [
                      SegmentedControl<ThemeMode>(
                        segments: [
                          (
                            value: ThemeMode.system,
                            label: 'settings_theme_short_system'.tr(),
                          ),
                          (
                            value: ThemeMode.dark,
                            label: 'settings_theme_short_dark'.tr(),
                          ),
                          (
                            value: ThemeMode.light,
                            label: 'settings_theme_short_light'.tr(),
                          ),
                        ],
                        selected: currentMode,
                        onChanged: (mode) =>
                            ref.read(themeProvider.notifier).setTheme(mode),
                      ),
                      Text(
                        themeHint.tr(),
                        style: text.bodySmall
                            ?.copyWith(color: c.text2, fontSize: 10.5),
                      ),
                    ],
                  ),

                  // ── Langue ────────────────────────────────────────────────
                  _Section(
                    label: 'settings_section_language'.tr(),
                    children: [
                      Row(
                        children: [
                          for (final (code, name) in const [
                            ('fr', 'Français'),
                            ('en', 'English'),
                            ('es', 'Español'),
                          ]) ...[
                            if (code != 'fr') const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: _LanguageButton(
                                code: code.toUpperCase(),
                                semanticsLabel: name,
                                selected:
                                    context.locale.languageCode == code,
                                onTap: () => context.setLocale(Locale(code)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // ── Liste locale (invité uniquement) ──────────────────────
                  if (isGuest)
                    _Section(
                      label: 'settings_section_local_list'.tr(),
                      children: [
                        _Card(
                          children: [
                            _SettingsRow(
                              icon: Icons.upload_rounded,
                              title: 'settings_export_title'.tr(),
                              subtitle: backup.key
                                  .tr(namedArgs: {'count': '${backup.days}'}),
                              busy: _isExporting,
                              onTap: _isExporting ? null : _export,
                            ),
                            Divider(height: 1, color: c.border),
                            _SettingsRow(
                              icon: Icons.download_rounded,
                              title: 'settings_import_title'.tr(),
                              subtitle: 'settings_import_subtitle'.tr(),
                              busy: _isImporting,
                              onTap: _isImporting ? null : _import,
                            ),
                          ],
                        ),
                        const _AccountNudge(),
                      ],
                    ),

                  // ── Application ───────────────────────────────────────────
                  _Section(
                    label: 'settings_section_app'.tr(),
                    children: [
                      _Card(
                        children: [
                          _SettingsRow(
                            icon: Icons.info_outline_rounded,
                            title: 'settings_version_title'.tr(),
                            trailing: Text(
                              appVersion,
                              style: AppTypography.overline(c.text2)
                                  .copyWith(fontSize: 12, letterSpacing: 0),
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18, color: c.accentText),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section : sur-titre mono + contenu espacé de 9 px.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: AppTypography.overline(c.text3)),
          for (final child in children) ...[
            const SizedBox(height: 9),
            child,
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.busy = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.surface2,
                borderRadius: BorderRadius.circular(9),
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.accentText),
                    )
                  : Icon(icon, size: 17, color: c.accentText),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.titleSmall
                          ?.copyWith(color: c.text1, fontSize: 12.5)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: text.bodySmall
                            ?.copyWith(color: c.text2, fontSize: 10.5)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null || busy)
              Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
          ],
        ),
      ),
    );
  }
}

/// Langue : trois boutons côte à côte, le choix actif en dégradé accent.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.code,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? c.accentGradient : null,
            color: selected ? null : c.surface1,
            borderRadius: BorderRadius.circular(11),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: selected ? null : onTap,
            child: SizedBox(
              height: AppSpacing.minTouch,
              child: Center(
                child: Text(
                  code,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                        color: selected ? Colors.white : c.text2,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encart invité : se connecter transfère la liste locale sans rien perdre.
class _AccountNudge extends StatelessWidget {
  const _AccountNudge();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark
            ? c.accent.withValues(alpha: 0.12)
            : const Color(0xFFE9EDFC),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('settings_account_title'.tr(),
              style:
                  text.titleSmall?.copyWith(color: c.text1, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('settings_account_body'.tr(),
              style: text.bodySmall?.copyWith(color: c.text2, height: 1.5)),
          const SizedBox(height: 10),
          AppButton(
            label: 'settings_account_cta'.tr(),
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}
