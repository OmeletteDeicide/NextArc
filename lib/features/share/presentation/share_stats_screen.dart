import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/constants/app_links.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/share/domain/share_providers.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:nextarc/features/stats/presentation/user_title_badge.dart';
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

// ── Identité affichée sur les cartes (selon les interrupteurs) ────────────────

class _ShareIdentity {
  const _ShareIdentity({
    required this.title,
    required this.showTitle,
    required this.showCrown,
    this.avatarUrl,
    this.name,
  });

  final UserTitle title;
  final bool showTitle;

  /// Couronne affichée (Arcer uniquement) : sur la photo si elle est visible,
  /// sinon dans la pastille du titre.
  final bool showCrown;

  /// Photo et pseudo, uniquement si l'utilisateur les a activés.
  final String? avatarUrl;
  final String? name;

  bool get isVisible => showTitle || avatarUrl != null;
}

// ── Corps principal : carrousel de cartes + options ───────────────────────────

class _ShareBody extends ConsumerStatefulWidget {
  const _ShareBody({required this.stats});
  final StatsModel stats;

  @override
  ConsumerState<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends ConsumerState<_ShareBody> {
  final _pageController = PageController();
  final _cardKeys = [GlobalKey(), GlobalKey()];
  int _page = 0;
  bool _sharing = false;

  bool _showTitle = true;
  bool _showPhoto = false; // vie privée : désactivé par défaut
  bool _showCrown = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _share({
    required int page,
    required List<String> imageUrls,
  }) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Les images réseau doivent être chargées avant la capture
      await Future.wait(imageUrls.map(
        (url) => precacheImage(CachedNetworkImageProvider(url), context),
      ));
      await Future.delayed(const Duration(milliseconds: 150));

      final boundary = _cardKeys[page].currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nextarc_share_$page.png');
      await file.writeAsBytes(pngBytes);

      final text =
          page == 1 ? 'share_favourites_text'.tr() : 'share_stats_text'.tr();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '$text\n${AppLinks.playStore}',
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
    final user = ref.watch(authProvider).whenOrNull(data: (a) => a.user);
    final favourites =
        ref.watch(shareFavouritesProvider).whenOrNull(data: (f) => f) ??
            const <FavouriteCover>[];
    final collage = favourites.take(collageSize(favourites.length)).toList();

    final title = widget.stats.title;
    final avatarUrl = user?.avatar;
    final identity = _ShareIdentity(
      title: title,
      showTitle: _showTitle,
      showCrown: title.isArcer && _showCrown,
      avatarUrl: _showPhoto ? avatarUrl : null,
      name: _showPhoto ? user?.displayName : null,
    );

    final cards = <Widget>[
      _StatsCard(stats: widget.stats, identity: identity),
      if (collage.isNotEmpty)
        _FavouritesCard(covers: collage, identity: identity),
    ];
    final page = math.min(_page, cards.length - 1);

    final imageUrls = [
      ?identity.avatarUrl,
      if (page == 1) ...collage.map((c) => c.coverUrl),
      if (page == 0) ...[
        ?widget.stats.bestAnime?.media.coverImage,
        ?widget.stats.bestManga?.media.coverImage,
      ],
    ];

    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Aperçu des cartes ─────────────────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: RepaintBoundary(key: _cardKeys[i], child: cards[i]),
              ),
            ),
          ),
        ),

        if (cards.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cards.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == page
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),

        // ── Options ───────────────────────────────────────────────────────
        _OptionSwitch(
          label: 'share_option_title'.tr(),
          value: _showTitle,
          onChanged: (v) => setState(() => _showTitle = v),
        ),
        if (avatarUrl != null)
          _OptionSwitch(
            label: 'share_option_photo'.tr(),
            value: _showPhoto,
            onChanged: (v) => setState(() => _showPhoto = v),
          ),
        if (title.isArcer)
          _OptionSwitch(
            label: 'share_option_crown'.tr(),
            value: _showCrown,
            onChanged: (v) => setState(() => _showCrown = v),
          ),

        // ── Bouton partager ───────────────────────────────────────────────
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: FilledButton.icon(
              onPressed: _sharing
                  ? null
                  : () => _share(page: page, imageUrls: imageUrls),
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

class _OptionSwitch extends StatelessWidget {
  const _OptionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ── Carte à partager ──────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.identity});
  final StatsModel stats;
  final _ShareIdentity identity;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      identity: identity,
      subtitle: 'share_card_subtitle'.tr(),
      content: (w, h) => [
        // Stats clés
        _CardStatRow(stats: stats, w: w),

        SizedBox(height: h * 0.04),

        // Genres
        if (stats.topGenres.isNotEmpty) ...[
          _CardGenreRow(genres: stats.topGenres, w: w),
          SizedBox(height: h * 0.04),
        ],

        // Jaquettes meilleurs anime/manga
        if (stats.bestAnime != null || stats.bestManga != null)
          _CardCovers(stats: stats, h: h * 0.25),

        const Spacer(),
      ],
    );
  }
}

// ── Carte « Mes préférés » ─────────────────────────────────────────────────────

class _FavouritesCard extends StatelessWidget {
  const _FavouritesCard({required this.covers, required this.identity});
  final List<FavouriteCover> covers;
  final _ShareIdentity identity;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      identity: identity,
      subtitle: 'share_card_favourites'.tr(),
      content: (w, h) => [
        Expanded(child: _CoverCollage(covers: covers, w: w)),
        SizedBox(height: h * 0.03),
      ],
    );
  }
}

/// Mosaïque de jaquettes (lignes de 3), dimensionnée pour tenir dans la carte.
class _CoverCollage extends StatelessWidget {
  const _CoverCollage({required this.covers, required this.w});
  final List<FavouriteCover> covers;
  final double w;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const coverRatio = 1.5; // hauteur / largeur d'une jaquette
        final rows = (covers.length / columns).ceil();
        final gap = w * 0.025;

        final maxCellWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final maxCellHeight =
            (constraints.maxHeight - gap * (rows - 1)) / rows;
        final cellHeight = math.min(maxCellWidth * coverRatio, maxCellHeight);
        final cellWidth = cellHeight / coverRatio;

        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final cover in covers)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: cellWidth,
                    height: cellHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: cover.coverUrl,
                          fit: BoxFit.cover,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                              stops: const [0.55, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 5,
                          right: 5,
                          bottom: 5,
                          child: Text(
                            cover.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: w * 0.024,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if ((cover.score ?? 0) > 0)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '★ ${cover.score!.toStringAsFixed(cover.score! % 1 == 0 ? 0 : 1)}',
                                style: TextStyle(
                                  color: const Color(0xFFFFC107),
                                  fontSize: w * 0.024,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Identité : photo (+ couronne), pseudo, titre ──────────────────────────────

class _CardIdentity extends StatelessWidget {
  const _CardIdentity({required this.identity, required this.w});
  final _ShareIdentity identity;
  final double w;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = identity.avatarUrl;
    return Row(
      children: [
        if (avatarUrl != null) ...[
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: w * 0.06,
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              ),
              if (identity.showCrown)
                Positioned(
                  top: -w * 0.045,
                  right: -w * 0.035,
                  child: ArcerCrown(size: w * 0.065),
                ),
            ],
          ),
          SizedBox(width: w * 0.035),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (identity.name != null)
                Text(
                  identity.name!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: w * 0.042,
                  ),
                ),
              if (identity.showTitle) ...[
                if (identity.name != null) SizedBox(height: w * 0.012),
                UserTitleBadge(
                  title: identity.title,
                  // Sans photo, la couronne se place dans la pastille
                  showCrown: identity.showCrown && avatarUrl == null,
                  fontSize: w * 0.034,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Cadre commun des cartes (fond, en-tête, identité, pied) ───────────────────

class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.identity,
    required this.subtitle,
    required this.content,
  });

  final _ShareIdentity identity;
  final String subtitle;

  /// Contenu entre l'en-tête et le pied ; doit contenir un élément flexible
  /// (Spacer / Expanded) pour occuper la hauteur restante.
  final List<Widget> Function(double w, double h) content;

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
                      _CardHeader(w: w, subtitle: subtitle),

                      if (identity.isVisible) ...[
                        SizedBox(height: h * 0.03),
                        _CardIdentity(identity: identity, w: w),
                      ],

                      SizedBox(height: h * 0.04),

                      ...content(w, h),

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
  const _CardHeader({required this.w, required this.subtitle});
  final double w;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            width: w * 0.1,
            height: w * 0.1,
            fit: BoxFit.cover,
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
              subtitle,
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
          // Réduit la taille plutôt que de couper (ex : « 41j 16h », « 9h 36min »)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: w * 0.055,
              ),
              maxLines: 1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: w * 0.028,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
            'share_card_store'.tr(),
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
