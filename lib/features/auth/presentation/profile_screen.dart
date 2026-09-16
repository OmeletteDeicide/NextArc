import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/core/widgets/google_logo.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/auth/presentation/anilist_actions.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:nextarc/features/stats/presentation/title_promotion_card.dart';
import 'package:nextarc/features/stats/presentation/user_title_badge.dart';
import 'package:nextarc/features/watchlist/data/mutation_repository.dart';
import 'package:nextarc/features/watchlist/data/watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran Profil — affiche le compte connecté ou propose de se connecter.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    // Détecte la transition non-connecté → connecté pour proposer la migration
    ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      final wasGuest = prev?.value?.isAuthenticated == false;
      final isNowAuth = next.value?.isAuthenticated == true;
      if (wasGuest && isNowAuth) {
        _checkGuestMigration(context, ref);
      }
    });

    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _buildError(context, e.toString()),
      data: (auth) => auth.isAuthenticated
          ? _buildProfile(context, ref, auth)
          : _buildLogin(context, ref, auth),
    );
  }

  // ── Écran connecté ────────────────────────────────────────────────────────

  Widget _buildProfile(BuildContext context, WidgetRef ref, AuthState auth) {
    final user = auth.user!;
    final stats = ref.watch(statsProvider).valueOrNull;
    final title = stats?.title;
    final c = AppColors.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: AppSpacing.lg + bottomInset),
        children: [
          _ProfileHeader(
            user: user,
            title: title,
            onEdit: user.hasFirebase
                ? () => context.push(AppRoutes.profileEdit)
                : null,
            onLogout: () => _confirmLogout(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  _ArcerRoadCard(
                    title: title,
                    onTap: () => context.push(AppRoutes.myTitle),
                  ),
                  const SizedBox(height: 11),
                ],
                _MenuRow(
                  icon: Icons.insights_rounded,
                  title: 'profile_stats_title'.tr(),
                  subtitle: stats == null
                      ? 'profile_stats_subtitle'.tr()
                      : 'profile_stats_summary'.tr(namedArgs: {
                          'episodes': NumberFormat.decimalPattern(
                                  context.locale.toString())
                              .format(stats.episodesWatched),
                          'time': stats.watchTimeFormatted,
                        }),
                  onTap: () => context.push(AppRoutes.stats),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (user.hasAnilist)
                  _MenuRow(
                    icon: Icons.link_rounded,
                    title: 'AniList',
                    subtitle: 'profile_anilist_connected'.tr(
                        namedArgs: {'name': user.anilistName ?? user.name}),
                    subtitleColor: c.statusCurrent,
                    // Compte NextArc : AniList peut être délié. AniList seul :
                    // c'est la déconnexion qui s'applique.
                    trailingLabel: user.hasFirebase
                        ? 'profile_anilist_unlink'.tr()
                        : null,
                    onTap: user.hasFirebase
                        ? () => confirmUnlinkAnilist(context, ref)
                        : null,
                  )
                else if (user.hasFirebase)
                  _MenuRow(
                    icon: Icons.link_rounded,
                    title: 'profile_link_anilist_title'.tr(),
                    subtitle: 'profile_link_anilist_subtitle'.tr(),
                    onTap: () => ref.read(authProvider.notifier).login(),
                  ),
                const SizedBox(height: AppSpacing.xs),
                _MenuRow(
                  icon: Icons.settings_outlined,
                  title: 'profile_settings_title'.tr(),
                  subtitle: 'profile_settings_summary'.tr(),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _SupportRow(),
                const SizedBox(height: AppSpacing.xs),
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  title: 'profile_about_title'.tr(),
                  subtitle: 'profile_about_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.about),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Écran non connecté ────────────────────────────────────────────────────

  /// Connexion : Google en principal, e-mail en secondaire, invité en lien.
  /// AniList n'est plus proposé ici : il se lie depuis un compte NextArc
  /// (les sessions « AniList seul » existantes restent restaurées).
  Widget _buildLogin(BuildContext context, WidgetRef ref, AuthState auth) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isLoading = ref.watch(authProvider).isLoading;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final hintStyle = text.bodySmall
        ?.copyWith(color: c.text3, fontSize: 10.5, height: 1.5);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              22, AppSpacing.md, 22, AppSpacing.lg + bottomInset),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/logo.png',
                    width: 44, height: 44, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'auth_promise_title'.tr(),
              style: text.headlineMedium?.copyWith(
                fontSize: 27,
                height: 1.12,
                letterSpacing: -1,
                color: c.text1,
              ),
            ),
            const SizedBox(height: 18),
            for (final key in const [
              'auth_benefit_list',
              'auth_benefit_recos',
              'auth_benefit_stats',
            ])
              _Benefit(label: key.tr()),
            if (auth.error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: c.favourite.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.cover),
                  border:
                      Border.all(color: c.favourite.withValues(alpha: 0.35)),
                ),
                child: Text(
                  auth.error!.tr(),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: c.statusDroppedText),
                ),
              ),
            ],
            const SizedBox(height: 26),
            AppButton(
              label: 'auth_continue_google'.tr(),
              leading: const GoogleLogo(),
              expand: true,
              loading: isLoading,
              onPressed: () =>
                  ref.read(authProvider.notifier).loginWithGoogle(),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'auth_continue_email'.tr(),
              icon: Icons.mail_outline_rounded,
              variant: AppButtonVariant.secondary,
              expand: true,
              onPressed:
                  isLoading ? null : () => context.push(AppRoutes.login),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: c.accentText),
                onPressed: () => context.go(AppRoutes.discover),
                child: Text('auth_continue_guest'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            Text('auth_guest_hint'.tr(),
                textAlign: TextAlign.center, style: hintStyle),
            const SizedBox(height: 6),
            Text('auth_anilist_later'.tr(),
                textAlign: TextAlign.center, style: hintStyle),
            const SizedBox(height: 28),
            _MenuRow(
              icon: Icons.settings_outlined,
              title: 'profile_settings_title'.tr(),
              subtitle: 'profile_settings_login_summary'.tr(),
              onTap: () => context.push(AppRoutes.settings),
            ),
            const SizedBox(height: AppSpacing.xs),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              title: 'profile_about_title'.tr(),
              subtitle: 'profile_about_subtitle'.tr(),
              onTap: () => context.push(AppRoutes.about),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
      body: Center(child: Text(error)),
    );
  }

  // ── Migration invité → Firestore (Firebase-only) ou AniList ──────────────

  Future<void> _checkGuestMigration(BuildContext context, WidgetRef ref) async {
    final guestEntries =
        await ref.read(guestWatchlistRepositoryProvider).getEntries();
    if (guestEntries.isEmpty || !context.mounted) return;

    final authState = ref.read(authProvider).value;
    if (authState == null || !authState.isAuthenticated) return;

    // Compte NextArc : la liste invité est fusionnée dans Firestore par
    // AuthNotifier dès la connexion (voir _syncInBackground).
    if (authState.user?.hasFirebase == true) return;

    // ── AniList seul → migration avec confirmation ────────────────────────
    if (authState.user?.hasAnilist != true) return;

    Set<int> existingIds = {};
    try {
      final anilistGroups =
          await WatchlistRepository().getUserList(authState.user!.id);
      existingIds = anilistGroups
          .expand((g) => g.entries)
          .map((e) => e.media.id)
          .toSet();
    } catch (_) {
      // Si le fetch échoue, on continue sans filtrer
    }

    final newEntries =
        guestEntries.where((e) => !existingIds.contains(e.animeId)).toList();
    final alreadyCount = guestEntries.length - newEntries.length;

    if (!context.mounted) return;

    if (newEntries.isEmpty) {
      // Tous les animes sont déjà sur AniList → nettoyage silencieux
      await ref.read(guestWatchlistRepositoryProvider).clearAll();
      ref.invalidate(guestWatchlistProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('profile_migration_already_synced'.tr())),
        );
      }
      return;
    }

    final skippedNote = alreadyCount > 0
        ? '\n($alreadyCount déjà présent(s) sur AniList → ignoré(s))'
        : '';

    final merge = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_migration_dialog_title'.tr()),
        content: Text(
          '${newEntries.length} anime(s) à ajouter sur ton compte AniList.$skippedNote',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('dialog_ignore'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('profile_migration_merge_button'.tr()),
          ),
        ],
      ),
    );

    if (merge != true || !context.mounted) return;

    final mutationRepo = MutationRepository();
    int success = 0;
    for (final entry in newEntries) {
      try {
        await mutationRepo.saveEntry(
          mediaId: entry.animeId,
          status: entry.status,
          score: entry.score,
          progress: entry.progress,
        );
        success++;
      } catch (_) {
        // Continue même si une entrée échoue
      }
    }

    await ref.read(guestWatchlistRepositoryProvider).clearAll();
    ref.invalidate(guestWatchlistProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == newEntries.length
                ? '$success anime(s) ajoutés à AniList ✓'
                : '$success / ${newEntries.length} anime(s) migrés (${newEntries.length - success} erreurs)',
          ),
        ),
      );
    }
  }

  // ── Confirmation logout ───────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider).valueOrNull?.user;
    final confirmed = await showConfirmDialog(
      context,
      title: 'logout_title'.tr(),
      // AniList seul : la liste vit sur AniList ; sinon sur le compte NextArc
      message: user?.usesAnilistList == true
          ? 'logout_body_anilist'.tr()
          : 'logout_body_nextarc'.tr(),
      confirmLabel: 'dialog_confirm_logout'.tr(),
      destructive: true,
    );
    if (confirmed) await ref.read(authProvider.notifier).logout();
  }
}

// ── Écran de connexion : bénéfice et logo Google ──────────────────────────────

class _Benefit extends StatelessWidget {
  const _Benefit({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 12, color: c.accentText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.text2, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête du profil ─────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.title,
    required this.onEdit,
    required this.onLogout,
  });

  final UserModel user;
  final UserTitle? title;
  final VoidCallback? onEdit;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final isArcer = title?.isArcer ?? false;

    // Sous le nom : e-mail pour un compte NextArc, identifiant pour AniList seul
    final subtitle = user.hasFirebase
        ? user.email
        : 'profile_anilist_id'.tr(namedArgs: {'id': '${user.id}'});

    final header = DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1B2140), c.surface1],
                stops: const [0, 0.7],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.accent, c.violet],
              ),
      ),
      child: Stack(
        children: [
          if (isDark)
            Positioned(
              right: -40,
              top: -50,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.violet.withValues(alpha: 0.45),
                        c.violet.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.7],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.screen - 4, topInset + 4, AppSpacing.screen - 4, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      _HeaderButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'profile_edit_title'.tr(),
                        onTap: onEdit!,
                      ),
                    _HeaderButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'profile_logout_button'.tr(),
                      onTap: onLogout,
                    ),
                  ],
                ),
                _Avatar(user: user, isArcer: isArcer),
                const SizedBox(height: 10),
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall?.copyWith(
                    color: isDark ? c.text1 : Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: isDark
                          ? c.text2
                          : Colors.white.withValues(alpha: 0.88),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                if (title != null) ...[
                  const SizedBox(height: 10),
                  _PulseOnPromotion(
                    child: UserTitleBadge(title: title!, onAccent: !isDark),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Icônes de la barre d'état claires sur l'en-tête coloré
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: header,
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.isArcer});

  final UserModel user;
  final bool isArcer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().characters.first.toUpperCase();

    final avatar = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDark ? c.accentGradient : null,
        color: isDark ? null : Colors.white,
        border: Border.all(
          width: 3,
          color: isDark
              ? const Color(0x99060A15)
              : Colors.white.withValues(alpha: 0.65),
        ),
        image: user.avatar == null
            ? null
            : DecorationImage(
                image: CachedNetworkImageProvider(user.avatar!),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: user.avatar == null
          ? Text(
              initial,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 32,
                    color: isDark ? Colors.white : c.accent,
                  ),
            )
          : null,
    );

    if (!isArcer) return avatar;

    // Couronne des Arcer, en haut à droite de la photo
    return SizedBox(
      width: 100,
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          avatar,
          const Positioned(right: 0, top: -6, child: ArcerCrown(size: 28)),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0x8C060A15)
                    : Colors.white.withValues(alpha: 0.2),
              ),
              child: Icon(
                icon,
                size: 17,
                color: isDark ? const Color(0xFFC3CDEA) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fait pulser une fois le badge de titre après un passage de palier
/// (agrandissement léger puis retour, 220 ms chacun).
class _PulseOnPromotion extends ConsumerStatefulWidget {
  const _PulseOnPromotion({required this.child});

  final Widget child;

  @override
  ConsumerState<_PulseOnPromotion> createState() => _PulseOnPromotionState();
}

class _PulseOnPromotionState extends ConsumerState<_PulseOnPromotion>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.transition * 2,
  );

  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.14)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.14, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 1,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pulseIfPending());
  }

  void _pulseIfPending() {
    if (!mounted || !ref.read(titleBadgePulseProvider)) return;
    ref.read(titleBadgePulseProvider.notifier).state = false;
    HapticFeedback.lightImpact();
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nouveau palier pendant que le profil est affiché
    ref.listen<bool>(titleBadgePulseProvider, (_, pending) {
      if (pending) _pulseIfPending();
    });
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// ── Route vers Arcer ──────────────────────────────────────────────────────────

class _ArcerRoadCard extends StatelessWidget {
  const _ArcerRoadCard({required this.title, required this.onTap});

  final UserTitle title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numbers = NumberFormat.decimalPattern(context.locale.toString());

    return Material(
      color: c.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title.isArcer
                          ? 'profile_road_reached'.tr()
                          : 'profile_road_title'.tr(),
                      style: text.titleLarge?.copyWith(
                        fontSize: 13.5,
                        color: title.isArcer ? c.star : c.text1,
                      ),
                    ),
                  ),
                  Text(
                    'profile_road_tier'.tr(namedArgs: {
                      'tier': '${title.tier}',
                      'count': '${UserTitle.tierCount}',
                    }),
                    style: text.labelSmall?.copyWith(
                      color: c.accentText,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _RoadGauge(
                label: 'profile_road_completed'.tr(),
                value:
                    '${numbers.format(title.totalCompleted)} / ${numbers.format(UserTitle.arcerMinCompleted)}',
                progress: title.arcerCompletedProgress,
              ),
              const SizedBox(height: 11),
              _RoadGauge(
                label: 'profile_road_hours'.tr(),
                value:
                    '${numbers.format(title.totalHours)} / ${numbers.format(UserTitle.arcerMinHours)} h',
                progress: title.arcerHoursProgress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadGauge extends StatelessWidget {
  const _RoadGauge({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label, style: style?.copyWith(color: c.text2))),
            Text(value, style: style?.copyWith(color: c.text1)),
          ],
        ),
        const SizedBox(height: 7),
        // Une avancée non nulle reste visible sur la jauge
        GradientProgressBar(
          value: progress == 0 ? 0 : progress.clamp(0.01, 1.0),
        ),
      ],
    );
  }
}

// ── Lignes de menu ────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailingLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;

  /// Action nommée à droite (« Délier ») à la place du chevron.
  final String? trailingLabel;

  /// Null → ligne informative, sans chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: c.accentText),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleSmall?.copyWith(color: c.text1)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: subtitleColor ?? c.text2,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null)
                Text(
                  trailingLabel!,
                  style: text.labelMedium?.copyWith(color: c.statusDroppedText),
                )
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded, size: 20, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne dorée « Soutenir NextArc » (Ko-fi).
class _SupportRow extends StatelessWidget {
  const _SupportRow();

  static const _url = 'https://ko-fi.com/espiegle';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleColor = isDark ? const Color(0xFFFFD98A) : const Color(0xFF7A4A00);
    final subColor = isDark ? const Color(0xFFC6A864) : const Color(0xFF8A5200);

    return Material(
      color: isDark ? c.star.withValues(alpha: 0.1) : const Color(0xFFFFF7E6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: c.star.withValues(alpha: isDark ? 0.28 : 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(_url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? c.star.withValues(alpha: 0.18)
                      : const Color(0xFFFFEFC9),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Image.asset('assets/images/kofi.png'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('profile_kofi_title'.tr(),
                        style: text.titleSmall?.copyWith(color: titleColor)),
                    const SizedBox(height: 2),
                    Text(
                      'profile_kofi_summary'.tr(),
                      style: text.bodySmall
                          ?.copyWith(color: subColor, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 16, color: subColor),
            ],
          ),
        ),
      ),
    );
  }
}
