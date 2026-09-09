import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/stats/domain/stats_provider.dart';

class ShareStatsScreen extends ConsumerWidget {
  const ShareStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('share_stats_title'.tr())),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (stats) => _ShareBody(stats: stats),
      ),
    );
  }
}

// ── Corps principal ───────────────────────────────────────────────────────────

class _ShareBody extends StatefulWidget {
  const _ShareBody({required this.stats});
  final StatsModel stats;

  @override
  State<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends State<_ShareBody> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // Attendre que les images réseau soient bien peintes
      await Future.delayed(const Duration(milliseconds: 150));

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nextarc_stats.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'share_stats_text'.tr(),
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
    return Column(
      children: [
        // ── Aperçu de la carte ────────────────────────────────────────────
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: RepaintBoundary(
                key: _cardKey,
                child: _StatsCard(stats: widget.stats),
              ),
            ),
          ),
        ),

        // ── Bouton partager ───────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                  minimumSize: const Size.fromHeight(52)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte à partager ──────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final StatsModel stats;

  @override
  Widget build(BuildContext context) {
    // Ratio 9:16 (story/reel)
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // ── Fond gradient ─────────────────────────────────────────
                Container(
                  width: w,
                  height: h,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A0F1E),
                        Color(0xFF0F1C3F),
                        Color(0xFF0D1530),
                        Color(0xFF050810),
                      ],
                      stops: [0.0, 0.3, 0.65, 1.0],
                    ),
                  ),
                ),

                // ── Décoration : cercles lumineux ─────────────────────────
                Positioned(
                  top: -w * 0.15,
                  right: -w * 0.15,
                  child: Container(
                    width: w * 0.7,
                    height: w * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF4F6EF5).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: h * 0.1,
                  left: -w * 0.2,
                  child: Container(
                    width: w * 0.6,
                    height: w * 0.6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF7C4DFF).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Contenu ───────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: w * 0.07, vertical: h * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + app name
                      _CardHeader(w: w),

                      SizedBox(height: h * 0.05),

                      // Stats clés
                      _CardStatRow(stats: stats, w: w),

                      SizedBox(height: h * 0.045),

                      // Genres
                      if (stats.topGenres.isNotEmpty) ...[
                        _CardGenreRow(genres: stats.topGenres, w: w),
                        SizedBox(height: h * 0.045),
                      ],

                      // Jaquettes meilleurs anime/manga
                      if (stats.bestAnime != null || stats.bestManga != null)
                        _CardCovers(stats: stats, h: h * 0.3),

                      const Spacer(),

                      // Tagline bas
                      _CardFooter(w: w),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── En-tête : logo + titre ────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.w});
  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: w * 0.1,
          height: w * 0.1,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF4F6EF5), Color(0xFF7C4DFF)],
            ),
          ),
          child: Center(
            child: Text(
              'N',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: w * 0.055,
              ),
            ),
          ),
        ),
        SizedBox(width: w * 0.035),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NextArc',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: w * 0.065,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'share_card_subtitle'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: w * 0.03,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Stats : 3 tuiles ──────────────────────────────────────────────────────────

class _CardStatRow extends StatelessWidget {
  const _CardStatRow({required this.stats, required this.w});
  final StatsModel stats;
  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: stats.episodesWatched.toString(),
            label: 'share_card_episodes'.tr(),
            icon: Icons.live_tv_outlined,
            w: w,
          ),
        ),
        SizedBox(width: w * 0.025),
        Expanded(
          child: _StatTile(
            value: stats.watchTimeFormatted,
            label: 'share_card_time'.tr(),
            icon: Icons.schedule_outlined,
            w: w,
            accent: true,
          ),
        ),
        SizedBox(width: w * 0.025),
        Expanded(
          child: _StatTile(
            value: stats.meanScore != null
                ? stats.meanScore!.toStringAsFixed(1)
                : '—',
            label: 'share_card_score'.tr(),
            icon: Icons.star_outlined,
            w: w,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.w,
    this.accent = false,
  });
  final String value;
  final String label;
  final IconData icon;
  final double w;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? const Color(0xFF4F6EF5) : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: w * 0.035, horizontal: w * 0.025),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? const Color(0xFF4F6EF5).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: w * 0.045),
          SizedBox(height: w * 0.02),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: w * 0.055,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: w * 0.028,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Genres : chips ────────────────────────────────────────────────────────────

class _CardGenreRow extends StatelessWidget {
  const _CardGenreRow({required this.genres, required this.w});
  final List<GenreStat> genres;
  final double w;

  @override
  Widget build(BuildContext context) {
    final shown = genres.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'share_card_genres'.tr().toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: w * 0.028,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: w * 0.025),
        Wrap(
          spacing: w * 0.02,
          runSpacing: w * 0.018,
          children: shown.map((g) {
            return Container(
              padding: EdgeInsets.symmetric(
                  horizontal: w * 0.035, vertical: w * 0.018),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F6EF5).withValues(alpha: 0.35),
                    const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color:
                        const Color(0xFF4F6EF5).withValues(alpha: 0.5)),
              ),
              child: Text(
                g.name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: w * 0.032,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Jaquettes meilleurs titres ────────────────────────────────────────────────

class _CardCovers extends StatelessWidget {
  const _CardCovers({required this.stats, required this.h});
  final StatsModel stats;
  final double h;

  @override
  Widget build(BuildContext context) {
    final covers = [
      if (stats.bestAnime?.media.coverImage != null)
        (
          url: stats.bestAnime!.media.coverImage!,
          title: stats.bestAnime!.media.displayTitle,
          score: stats.bestAnime!.formattedScore ?? '',
        ),
      if (stats.bestManga?.media.coverImage != null)
        (
          url: stats.bestManga!.media.coverImage!,
          title: stats.bestManga!.media.displayTitle,
          score: stats.bestManga!.formattedScore ?? '',
        ),
    ];

    if (covers.isEmpty) return const SizedBox.shrink();

    return Row(
      children: covers.map((c) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: c == covers.last ? 0 : 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  SizedBox(
                    height: h,
                    child: CachedNetworkImage(
                      imageUrl: c.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  // Gradient + titre
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.score.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 10, color: Color(0xFFFFC107)),
                              const SizedBox(width: 2),
                              Text(
                                c.score,
                                style: const TextStyle(
                                  color: Color(0xFFFFC107),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        Text(
                          c.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Pied de carte ─────────────────────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.w});
  final double w;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'share_card_tagline'.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: w * 0.028,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: w * 0.03, vertical: w * 0.015),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F6EF5), Color(0xFF7C4DFF)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'nextarc.app',
            style: TextStyle(
              color: Colors.white,
              fontSize: w * 0.028,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
