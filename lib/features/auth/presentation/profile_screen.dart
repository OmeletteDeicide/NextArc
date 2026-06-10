import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';

/// Écran Profil — affiche le compte AniList connecté ou propose de se connecter.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

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
        title: const Text('Profil'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Déconnexion'),
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

                // Carte "Paramètres"
                _ProfileCard(
                  icon: Icons.settings_outlined,
                  title: 'Paramètres',
                  subtitle: 'Apparence, thème sombre / clair',
                  onTap: () => context.push(AppRoutes.settings),
                ),

                const SizedBox(height: 8),

                // Carte "À propos"
                _ProfileCard(
                  icon: Icons.info_outline_rounded,
                  title: 'À propos',
                  subtitle: 'Crédits, données AniList, technologies',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 80, color: Colors.white24),
              const SizedBox(height: 24),
              const Text(
                'Connecte-toi avec AniList',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Retrouve ta liste perso, tes notes et tes favoris.\nDébloque les recommandations personnalisées.',
                style: TextStyle(color: Colors.white54, height: 1.5),
                textAlign: TextAlign.center,
              ),

              // Message d'erreur éventuel
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
                  label: const Text('Se connecter avec AniList'),
                  onPressed: () => ref.read(authProvider.notifier).login(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(child: Text(error)),
    );
  }

  // ── Confirmation logout ───────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Tu veux vraiment te déconnecter de NextArc ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
    }
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
