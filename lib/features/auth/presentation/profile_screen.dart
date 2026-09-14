import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/data/mutation_repository.dart';
import 'package:nextarc/features/watchlist/data/watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran Profil — affiche le compte AniList connecté ou propose de se connecter.
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

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          if (user.hasFirebase)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'profile_edit_title'.tr(),
              onPressed: () => context.push(AppRoutes.profileEdit),
            ),
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: Text('profile_logout_button'.tr()),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Bannière + avatar ──────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                height: 140,
                color: const Color(0xFF1A1A1A),
                child: user.bannerImage != null
                    ? CachedNetworkImage(
                        imageUrl: user.bannerImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : null,
              ),
              Positioned(
                bottom: -40,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F0F0F),
                      width: 4,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage: user.avatar != null
                        ? CachedNetworkImageProvider(user.avatar!)
                        : null,
                    child: user.avatar == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 52),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (user.hasAnilist)
                  Text(
                    'profile_anilist_id'.tr(namedArgs: {'id': '${user.id}'}),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
                  )
                else if (user.email != null)
                  Text(
                    user.email!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),

                const SizedBox(height: 24),

                // Lier AniList (si Firebase-only)
                if (user.hasFirebase && !user.hasAnilist) ...[
                  _ProfileCard(
                    icon: Icons.link_rounded,
                    title: 'profile_link_anilist_title'.tr(),
                    subtitle: 'profile_link_anilist_subtitle'.tr(),
                    onTap: () => ref.read(authProvider.notifier).login(),
                  ),
                  const SizedBox(height: 8),
                ],

                _ProfileCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'profile_stats_title'.tr(),
                  subtitle: 'profile_stats_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.stats),
                ),
                const SizedBox(height: 8),
                _ProfileCard(
                  icon: Icons.settings_outlined,
                  title: 'profile_settings_title'.tr(),
                  subtitle: 'profile_settings_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.settings),
                ),
                const SizedBox(height: 8),
                const _KofiCard(),
                const SizedBox(height: 8),
                _ProfileCard(
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

          _ProfileCard(
            icon: Icons.settings_outlined,
            title: 'profile_settings_title'.tr(),
            subtitle: 'profile_settings_subtitle'.tr(),
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 8),
          const _KofiCard(),
          const SizedBox(height: 8),
          _ProfileCard(
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

// ── Widget Ko-fi ──────────────────────────────────────────────────────────────

class _KofiCard extends StatelessWidget {
  const _KofiCard();

  static const _url = 'https://ko-fi.com/espiegle';

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => launchUrl(
          Uri.parse(_url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Image.asset(
                'assets/images/kofi.png',
                height: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile_kofi_title'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'profile_kofi_subtitle'.tr(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget carte profil ────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: cs.onSurface.withValues(alpha: 0.38),
        ),
        onTap: onTap,
      ),
    );
  }
}
