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
              // Bannière
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
              // Avatar
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
                // Pseudo
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID AniList : ${user.id}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),

                const SizedBox(height: 24),

                // Carte "Mes statistiques"
                _ProfileCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'profile_stats_title'.tr(),
                  subtitle: 'profile_stats_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.stats),
                ),

                const SizedBox(height: 8),

                // Carte "Paramètres"
                _ProfileCard(
                  icon: Icons.settings_outlined,
                  title: 'profile_settings_title'.tr(),
                  subtitle: 'profile_settings_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.settings),
                ),

                const SizedBox(height: 8),

                // Bouton Ko-fi
                const _KofiCard(),

                const SizedBox(height: 8),

                // Carte "À propos"
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
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
      body: ListView(
        padding: const EdgeInsets.all(32),
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
                color: Colors.red.shade900.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                auth.error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.login),
              label: Text('profile_login_button'.tr()),
              onPressed: () => ref.read(authProvider.notifier).login(),
            ),
          ),

          const SizedBox(height: 48),
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
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(title: Image.asset('assets/images/logo.png', height: 40)),
      body: Center(child: Text(error)),
    );
  }

  // ── Migration invité → AniList ────────────────────────────────────────────

  Future<void> _checkGuestMigration(BuildContext context, WidgetRef ref) async {
    final guestEntries =
        await ref.read(guestWatchlistRepositoryProvider).getEntries();
    if (guestEntries.isEmpty || !context.mounted) return;

    // Récupère la liste AniList existante pour éviter d'écraser ses données
    final authState = ref.read(authProvider).value;
    if (authState == null || !authState.isAuthenticated) return;

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
