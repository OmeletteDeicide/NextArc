import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';

/// Jaquette 2:3 (placeholder si pas d'image), avec numéro de classement et
/// élément superposé optionnels.
class MediaCover extends StatelessWidget {
  const MediaCover({
    super.key,
    required this.imageUrl,
    this.rank,
    this.radius = AppRadius.cover,
    this.heroTag,
    this.overlay,
  });

  final String? imageUrl;

  /// Numéro de classement affiché en haut à gauche (« 01 »).
  final int? rank;
  final double radius;
  final String? heroTag;

  /// Widget posé en bas à droite (bouton d'action…).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = imageUrl;

    Widget placeholder() => ColoredBox(
          color: c.surface2,
          child: Center(
            child: Icon(Icons.image_outlined, color: c.text3, size: 28),
          ),
        );

    Widget cover = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: url == null
            ? placeholder()
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder(),
                errorWidget: (_, _, _) => placeholder(),
              ),
      ),
    );
    if (heroTag != null) cover = Hero(tag: heroTag!, child: cover);

    if (rank == null && overlay == null) return cover;

    return Stack(
      children: [
        cover,
        if (rank != null)
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xs,
            child: Text(
              rank!.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 15,
                height: 1,
                color: Colors.white.withValues(alpha: 0.9),
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 6),
                ],
              ),
            ),
          ),
        if (overlay != null)
          Positioned(right: 0, bottom: 0, child: overlay!),
      ],
    );
  }
}

/// Carte média : jaquette + titre (2 lignes max) + note et méta.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.score,
    this.meta,
    this.rank,
    this.heroTag,
    this.onTap,
    this.onAction,
    this.inList = false,
  });

  final String title;
  final String? imageUrl;

  /// Note formatée (« 8,7 »), affichée avec une étoile.
  final String? score;

  /// Info secondaire (« 12 ép. »).
  final String? meta;
  final int? rank;
  final String? heroTag;
  final VoidCallback? onTap;

  /// Action rapide (ajout / édition dans la liste).
  final VoidCallback? onAction;

  /// Le média est déjà dans la liste (icône d'édition au lieu d'ajout).
  final bool inList;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MediaCover(
            imageUrl: imageUrl,
            rank: rank,
            heroTag: heroTag,
            overlay: onAction == null
                ? null
                : _CoverActionButton(inList: inList, onTap: onAction!),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: c.text1, height: 1.25),
          ),
          if (score != null || meta != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                if (score != null) ...[
                  Icon(Icons.star_rounded, size: 13, color: c.star),
                  const SizedBox(width: 2),
                  Text(
                    score!,
                    style: text.bodySmall
                        ?.copyWith(color: c.star, fontWeight: FontWeight.w600),
                  ),
                  if (meta != null) const SizedBox(width: AppSpacing.xs),
                ],
                if (meta != null)
                  Flexible(
                    child: Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.text2),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bouton rond discret posé sur la jaquette, zone tactile 44 px.
class _CoverActionButton extends StatelessWidget {
  const _CoverActionButton({required this.inList, required this.onTap});

  final bool inList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xB3060A15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Icon(
                inList ? Icons.edit_outlined : Icons.add_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
