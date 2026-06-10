import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/theme/app_theme.dart';
import 'package:nextarc/features/detail/domain/detail_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';

/// Carte anime verticale — jaquette + titre + score.
/// Utilisée dans les listes horizontales et la grille de recherche.
class AnimeCard extends ConsumerWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    required this.onTap,
    this.width = 120,
    this.onWatchlistTap,
    this.heroTag,
  });

  final MediaModel anime;
  final VoidCallback onTap;
  final double width;

  /// Tag Hero unique passé par le parent. Si null, pas de Hero.
  final String? heroTag;

  /// Si fourni, affiche un bouton watchlist sur la jaquette.
  final VoidCallback? onWatchlistTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isInWatchlist = ref.watch(userListEntryProvider(anime.id)) != null;

    final jacket = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            anime.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: anime.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => _CardPlaceholder(cs: cs),
                    errorWidget: (ctx, url, err) => _CardPlaceholder(cs: cs),
                  )
                : _CardPlaceholder(cs: cs),

            // Bouton watchlist (optionnel)
            if (onWatchlistTap != null)
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onWatchlistTap,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isInWatchlist
                          ? Icons.edit_outlined
                          : Icons.bookmark_add_outlined,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: ClipRect(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Jaquette (avec Hero si tag fourni) ────────────────────────
              heroTag != null
                  ? Hero(tag: heroTag!, child: jacket)
                  : jacket,

              const SizedBox(height: 6),

              // ── Titre ──────────────────────────────────────────────────────
              Text(
                anime.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: cs.onSurface,
                ),
              ),

              // ── Score ──────────────────────────────────────────────────────
              if (anime.formattedScore != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 12, color: kStarColor),
                    const SizedBox(width: 2),
                    Text(
                      anime.formattedScore!,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder gris adaptatif affiché pendant le chargement de l'image.
class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.onSurface.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: cs.onSurface.withValues(alpha: 0.24),
          size: 32,
        ),
      ),
    );
  }
}
