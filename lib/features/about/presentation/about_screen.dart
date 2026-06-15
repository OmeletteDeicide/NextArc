import 'package:flutter/material.dart';

/// Écran "À propos" — crédits AniList + infos app.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Logo / nom app ─────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1C3F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'NextArc',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.38),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Description ────────────────────────────────────────────────
          const Text(
            'À propos de NextArc',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'NextArc est une application de suivi d\'animes et de recommandations personnalisées. '
            'Elle te permet de retrouver ta liste AniList, d\'explorer les tendances et de '
            'découvrir de nouveaux animes basés sur tes goûts.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),

          const SizedBox(height: 28),
          Divider(color: cs.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 20),

          // ── Crédits AniList ────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Données fournies par',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _CreditCard(
            icon: Icons.data_object_rounded,
            title: 'AniList',
            subtitle:
                'Toutes les données anime (titres, images, notes, listes utilisateur) '
                'proviennent de l\'API AniList. NextArc n\'est pas affilié à AniList.',
            url: 'https://anilist.co',
          ),
          const SizedBox(height: 12),
          _CreditCard(
            icon: Icons.code_rounded,
            title: 'AniList GraphQL API',
            subtitle: 'API publique utilisée conformément aux conditions '
                'd\'utilisation d\'AniList (anilist.gitbook.io/anilist-apiv2-docs).',
            url: 'https://anilist.gitbook.io/anilist-apiv2-docs',
          ),

          const SizedBox(height: 28),
          Divider(color: cs.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 20),

          // ── Stack technique ────────────────────────────────────────────
          const Text(
            'Technologies',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TechChip('Flutter'),
              _TechChip('Riverpod'),
              _TechChip('GraphQL'),
              _TechChip('Hive'),
              _TechChip('go_router'),
              _TechChip('AniList API'),
            ],
          ),

          const SizedBox(height: 28),
          Divider(color: cs.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 20),

          // ── Développeur ────────────────────────────────────────────────
          const Text(
            'Développeur',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Développé par Espiègle · 2026',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          Text(
            'Projet réalisé à des fins d\'apprentissage et de portfolio.',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Widget carte crédit ────────────────────────────────────────────────────────

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  url,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip technologie ──────────────────────────────────────────────────────────

class _TechChip extends StatelessWidget {
  const _TechChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: cs.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
