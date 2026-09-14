import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nextarc/features/discover/domain/media_model.dart';

/// Ouvre le bottom sheet de partage pour un anime ou manga.
Future<void> showShareMediaSheet(BuildContext context, MediaModel media) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareMediaSheet(media: media),
  );
}

class _ShareMediaSheet extends StatefulWidget {
  const _ShareMediaSheet({required this.media});
  final MediaModel media;

  @override
  State<_ShareMediaSheet> createState() => _ShareMediaSheetState();
}

class _ShareMediaSheetState extends State<_ShareMediaSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      await Future.delayed(const Duration(milliseconds: 150));

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/nextarc_share_${widget.media.id}.png');
      await file.writeAsBytes(pngBytes);

      final type = widget.media.isManga ? 'manga' : 'anime';
      final url = 'https://anilist.co/$type/${widget.media.id}';
      final title =
          'share_media_text'.tr(namedArgs: {'title': widget.media.displayTitle});
      final text = '$title\n$url';

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('share_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('share_media_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // ── Aperçu de la carte ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: RepaintBoundary(
              key: _cardKey,
              child: _MediaShareCard(media: widget.media),
            ),
          ),

          // ── Bouton Partager ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text('share_stats_button'.tr()),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte média partageable ───────────────────────────────────────────────────

class _MediaShareCard extends StatelessWidget {
  const _MediaShareCard({required this.media});
  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Fond : jaquette floutée ───────────────────────────────────
            if (media.coverImage != null)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: CachedNetworkImage(
                  imageUrl: media.coverImage!,
                  fit: BoxFit.cover,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),

            // ── Contenu centré ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo NextArc
                  _ShareLogo(),

                  const SizedBox(height: 20),

                  // Jaquette principale
                  if (media.coverImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 180,
                        width: 120,
                        child: CachedNetworkImage(
                          imageUrl: media.coverImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Score
                  if (media.averageScore != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          media.formattedScore ?? '',
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Titre
                  Text(
                    media.displayTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Titre romaji/english secondaire
                  if (media.titleEnglish != null &&
                      media.titleEnglish != media.displayTitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      media.titleEnglish!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Genres
                  if (media.genres != null && media.genres!.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: media.genres!.take(3).map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const Spacer(),

                  // Footer
                  _ShareCardFooter(media: media),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo NextArc miniature ────────────────────────────────────────────────────

class _ShareLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F6EF5), Color(0xFF7C4DFF)],
            ),
          ),
          child: const Center(
            child: Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'NextArc',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ── Footer de la carte ────────────────────────────────────────────────────────

class _ShareCardFooter extends StatelessWidget {
  const _ShareCardFooter({required this.media});
  final MediaModel media;

  @override
  Widget build(BuildContext context) {
    final type = media.isManga ? 'manga' : 'anime';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'share_card_via'.tr(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F6EF5), Color(0xFF7C4DFF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'anilist.co/$type/${media.id}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
