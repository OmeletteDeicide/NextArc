import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/zigzag_background.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
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
    final stats = ref.watch(statsProvider).value;
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
                    subtitle: 'profile_anilist_connected'
                        .tr(namedArgs: {'name': user.name}),
                    subtitleColor: c.statusCurrent,
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

  Widget _buildLogin(BuildContext context, WidgetRef ref, AuthState auth) {
    final cs = Theme.of(context).colorScheme;
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.account_circle_outlined,
              size: 80, color: cs.onSurface.withValues(alpha: 0.24)),
          const SizedBox(height: 24),
          Text(
            'profile_login_title'.tr(),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'profile_login_description'.tr(),
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.54), height: 1.5),
            textAlign: TextAlign.center,
          ),

          if (auth.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                auth.error!.tr(),
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Google ────────────────────────────────────────────────────
          _SocialButton(
            label: 'auth_continue_google'.tr(),
            icon: _GoogleIcon(),
            loading: isLoading,
            onPressed: () => ref.read(authProvider.notifier).loginWithGoogle(),
          ),

          const SizedBox(height: 12),

          // ── Email ─────────────────────────────────────────────────────
          OutlinedButton.icon(
            icon: const Icon(Icons.email_outlined),
            label: Text('auth_continue_email'.tr()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: isLoading ? null : () => context.push(AppRoutes.login),
          ),

          const SizedBox(height: 24),

          // ── Séparateur ────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'auth_or'.tr(),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.4), fontSize: 13),
              ),
            ),
            const Expanded(child: Divider()),
          ]),

          const SizedBox(height: 16),

          // ── AniList (secondaire) ──────────────────────────────────────
          TextButton.icon(
            icon: const Icon(Icons.link_rounded, size: 18),
            label: Text('profile_login_button'.tr()),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: isLoading
                ? null
                : () => ref.read(authProvider.notifier).login(),
          ),

          const SizedBox(height: 40),

          _MenuRow(
            icon: Icons.settings_outlined,
            title: 'profile_settings_title'.tr(),
            subtitle: 'profile_settings_summary'.tr(),
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 8),
          const _SupportRow(),
          const SizedBox(height: 8),
          _MenuRow(
            icon: Icons.info_outline_rounded,
            title: 'profile_about_title'.tr(),
            subtitle: 'profile_about_subtitle'.tr(),
            onTap: () => context.push(AppRoutes.about),
          ),
          const SizedBox(height: 24),
        ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_logout_dialog_title'.tr()),
        content: Text('profile_logout_dialog_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('dialog_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('dialog_confirm_logout'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
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
      child: ZigzagBackground(
        color: isDark ? c.violet : Colors.white,
        opacity: isDark ? 0.42 : 0.2,
        alwaysVisible: true,
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
                    UserTitleBadge(title: title!, onAccent: !isDark),
                  ],
                ],
              ),
            ),
          ],
        ),
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;

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
              if (onTap != null)
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

// ── Bouton social générique ───────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Icône Google SVG simplifiée en Container coloré
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
