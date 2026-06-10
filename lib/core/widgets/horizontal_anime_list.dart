import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/core/widgets/anime_card.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';

/// Section horizontale scrollable avec titre, gestion loading/erreur/vide.
class HorizontalAnimeList extends StatelessWidget {
  const HorizontalAnimeList({
    super.key,
    required this.title,
    required this.asyncValue,
    required this.onAnimeTap,
    required this.onRetry,
    required this.sectionKey,
    this.onWatchlistTap,
  });

  final String title;
  final AsyncValue<PaginatedResult> asyncValue;

  /// Reçoit l'animeId ET le heroTag unique généré par cette section.
  final void Function(int animeId, String heroTag) onAnimeTap;
  final VoidCallback onRetry;

  /// Préfixe unique pour les tags Hero de cette section (ex: 'trending', 'seasonal').
  final String sectionKey;

  /// Si fourni, active le bouton watchlist sur chaque carte.
  final void Function(MediaModel anime)? onWatchlistTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre de section ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // ── Contenu ────────────────────────────────────────────────────────
        SizedBox(
          height: 260,
          child: asyncValue.when(
            loading: () => _buildLoading(),
            error: (error, _) => _buildError(error),
            data: (result) => result.items.isEmpty
                ? _buildEmpty()
                : _buildList(result),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6,
      separatorBuilder: (_, idx) => const SizedBox(width: 12),
      itemBuilder: (_, idx) => const _ShimmerCard(),
    );
  }

  Widget _buildError(Object error) {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: cs.onSurface.withValues(alpha: 0.38), size: 32),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildEmpty() {
    return Builder(builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Text(
          'Aucun anime disponible',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
        ),
      );
    });
  }

  Widget _buildList(PaginatedResult result) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: result.items.length,
      separatorBuilder: (_, idx) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final anime = result.items[index];
        final tag = '${sectionKey}_$index';
        return AnimeCard(
          anime: anime,
          heroTag: tag,
          onTap: () => onAnimeTap(anime.id, tag),
          onWatchlistTap: onWatchlistTap != null
              ? () => onWatchlistTap!(anime)
              : null,
        );
      },
    );
  }
}

/// Carte shimmer (placeholder pendant le chargement).
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    final shimmer =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(color: shimmer),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            width: 100,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            width: 60,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
