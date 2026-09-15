import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/zigzag_background.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/discover/domain/discover_hero.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Note AniList formatée selon la langue (« 8,4 » en FR/ES, « 8.4 » en EN).
String? _localizedScore(BuildContext context, MediaModel media) {
  final score = media.formattedScore;
  if (score == null) return null;
  return context.locale.languageCode == 'en'
      ? score
      : score.replaceAll('.', ',');
}

/// « 12 ép. » / « 80 ch. » selon le type de média.
String? _countLabel(MediaModel media) {
  if (media.isManga) {
    final chapters = media.chapters;
    return chapters == null
        ? null
        : 'meta_chapters'.tr(namedArgs: {'count': '$chapters'});
  }
  final episodes = media.episodes;
  return episodes == null
      ? null
      : 'meta_episodes'.tr(namedArgs: {'count': '$episodes'});
}

void _openDetail(BuildContext context, MediaModel media, String heroTag) {
  context.push('/detail/${media.id}',
      extra: {'heroTag': heroTag, 'coverUrl': media.coverImage});
}

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingAnimeProvider);
    final seasonal = ref.watch(seasonalAnimeProvider);
    final trendingManga = ref.watch(trendingMangaProvider);
    final releasingManga = ref.watch(releasingMangaProvider);
    final preference = ref.watch(contentPreferenceProvider);
    final hero = ref.watch(discoverHeroProvider);

    /// « Tout voir » : ouvre Explorer avec les filtres de la section.
    void seeAll(FilterParams params) {
      ref.read(browseFilterProvider.notifier).state = params;
      context.push(AppRoutes.browse);
    }

    final animeRails = [
      _MediaRail(
        title: 'discover_trending_anime'.tr(),
        asyncValue: trending,
        sectionKey: 'trending',
        ranked: true,
        onRetry: () => ref.invalidate(trendingAnimeProvider),
        onSeeAll: () => seeAll(
            const FilterParams(mediaType: 'ANIME', sort: 'TRENDING_DESC')),
      ),
      _MediaRail(
        title: 'discover_seasonal_anime'.tr(),
        asyncValue: seasonal,
        sectionKey: 'seasonal',
        onRetry: () => ref.invalidate(seasonalAnimeProvider),
        onSeeAll: () => seeAll(const FilterParams(
            mediaType: 'ANIME', status: 'RELEASING', sort: 'POPULARITY_DESC')),
      ),
    ];

    final mangaRails = [
      _MediaRail(
        title: 'discover_trending_manga'.tr(),
        asyncValue: trendingManga,
        sectionKey: 'trending_manga',
        ranked: true,
        onRetry: () => ref.invalidate(trendingMangaProvider),
        onSeeAll: () => seeAll(
            const FilterParams(mediaType: 'MANGA', sort: 'TRENDING_DESC')),
      ),
      _MediaRail(
        title: 'discover_releasing_manga'.tr(),
        asyncValue: releasingManga,
        sectionKey: 'releasing_manga',
        onRetry: () => ref.invalidate(releasingMangaProvider),
        onSeeAll: () => seeAll(const FilterParams(
            mediaType: 'MANGA', status: 'RELEASING', sort: 'POPULARITY_DESC')),
      ),
    ];

    // Ordre dynamique : manga d'abord si l'utilisateur a plus de manga
    final rails = preference == 'MANGA'
        ? [...mangaRails, ...animeRails]
        : [...animeRails, ...mangaRails];

    return Scaffold(
      body: ZigzagBackground(
        // Le design ne met le motif en clair que sur les fonds accentués
        showInLight: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trendingAnimeProvider);
            ref.invalidate(seasonalAnimeProvider);
            ref.invalidate(trendingMangaProvider);
            ref.invalidate(releasingMangaProvider);
            await Future.wait([
              ref.read(trendingAnimeProvider.future),
              ref.read(seasonalAnimeProvider.future),
              ref.read(trendingMangaProvider.future),
              ref.read(releasingMangaProvider.future),
            ]);
          },
          child: CustomScrollView(
            slivers: [
              const SliverSafeArea(
                bottom: false,
                sliver: SliverToBoxAdapter(child: _DiscoverHeader()),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, 0),
                  child: hero != null
                      ? _HeroCard(hero: hero)
                      : trending.isLoading
                          ? const _HeroSkeleton()
                          : const SizedBox.shrink(),
                ),
              ),
              SliverList(delegate: SliverChildListDelegate(rails)),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── En-tête : logo + recherche + filtres ──────────────────────────────────────

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.xs, AppSpacing.screen - 4, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Image.asset('assets/images/logo.png',
                width: 30, height: 30, fit: BoxFit.cover),
          ),
          const SizedBox(width: 9),
          Text(
            'NextArc',
            style: text.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const Spacer(),
          _RoundIconButton(
            icon: Icons.search_rounded,
            tooltip: 'search_hint'.tr(),
            onTap: () => context.push(AppRoutes.search),
            color: c.text2,
          ),
          _RoundIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'browse_filters'.tr(),
            onTap: () => context.push(AppRoutes.browse),
            color: c.text2,
          ),
        ],
      ),
    );
  }
}

/// Bouton rond de 36 px dans une zone tactile de 44 px.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration:
                  BoxDecoration(color: c.surface2, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Média mis en avant ────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero});

  static const double height = 196;
  static const double radius = 16;

  final DiscoverHero hero;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = hero.media;
    final heroTag = 'discover_hero_${media.id}';
    final imageUrl = media.bannerImage ?? media.coverImage;

    final label = switch (hero.kind) {
      DiscoverHeroKind.today => 'discover_hero_today'.tr(),
      DiscoverHeroKind.upcoming => 'discover_hero_upcoming'.tr(),
      DiscoverHeroKind.trending => 'discover_hero_trending'.tr(),
    };

    final meta = <String>[];
    final next = media.nextAiringEpisode;
    if (next != null && hero.kind != DiscoverHeroKind.trending) {
      meta.add('meta_episode_number'
          .tr(namedArgs: {'number': '${next.episode}'}));
      final countdown = airingCountdown(next.airingAt.difference(DateTime.now()));
      meta.add(countdown.key.tr(namedArgs: {'count': '${countdown.count}'}));
    } else if (_countLabel(media) case final count?) {
      meta.add(count);
    }
    final score = _localizedScore(context, media);

    return Semantics(
      button: true,
      label: '$label — ${media.displayTitle}',
      child: GestureDetector(
        onTap: () => _openDetail(context, media, heroTag),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    // Sans bannière, la jaquette est cadrée sur le haut
                    alignment: media.bannerImage == null
                        ? Alignment.topCenter
                        : Alignment.center,
                    placeholder: (_, _) => ColoredBox(color: c.surface2),
                    errorWidget: (_, _, _) => ColoredBox(color: c.surface2),
                  )
                else
                  ColoredBox(color: c.surface2),
                // Voile pour la lisibilité du texte (sombre dans les 2 thèmes)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xF7060A15), Color(0x0D060A15)],
                      stops: [0.14, 0.66],
                    ),
                  ),
                ),
                if (isDark)
                  Positioned(
                    right: -30,
                    top: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            c.violet.withValues(alpha: 0.4),
                            c.violet.withValues(alpha: 0),
                          ]),
                        ),
                      ),
                    ),
                  )
                else
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ZigzagPainter(color: Color(0x29FFFFFF)),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: c.accentGradient,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      label.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        media.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall
                            ?.copyWith(color: const Color(0xFFF7F9FF)),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: meta.join(' · ')),
                          if (score != null) ...[
                            if (meta.isNotEmpty) const TextSpan(text: ' · '),
                            TextSpan(
                              text: '★ $score',
                              style: const TextStyle(color: Color(0xFFFFC145)),
                            ),
                          ],
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall
                            ?.copyWith(color: const Color(0xFFC3CDEA)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _HeroCard.height,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface1,
        borderRadius: BorderRadius.circular(_HeroCard.radius),
      ),
    );
  }
}

// ── Section horizontale ───────────────────────────────────────────────────────

class _MediaRail extends StatelessWidget {
  const _MediaRail({
    required this.title,
    required this.asyncValue,
    required this.sectionKey,
    required this.onRetry,
    required this.onSeeAll,
    this.ranked = false,
  });

  final String title;
  final AsyncValue<PaginatedResult> asyncValue;

  /// Préfixe unique des tags Hero de la section.
  final String sectionKey;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;

  /// Affiche le rang (01, 02…) sur les jaquettes.
  final bool ranked;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // ~2 cartes visibles avec un aperçu de la 3ᵉ pour inviter au défilement
    final cardWidth = math.min(
      200.0,
      math.max(
          120.0, (screenWidth - AppSpacing.screen * 2 - AppSpacing.sm) / 2.25),
    );
    // jaquette 2:3 + titre sur 2 lignes + ligne de méta
    final railHeight = cardWidth * 1.5 + 70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, AppSpacing.lg, AppSpacing.screen - 8, 4),
          child: SectionHeader(
            title: title,
            actionLabel: 'discover_see_all'.tr(),
            onAction: onSeeAll,
          ),
        ),
        SizedBox(
          height: railHeight,
          child: asyncValue.when(
            loading: () => _RailSkeleton(cardWidth: cardWidth),
            error: (_, _) => _RailError(onRetry: onRetry),
            data: (result) {
              if (result.items.isEmpty) {
                return Center(
                  child: Text(
                    'horizontal_list_empty'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                itemCount: result.items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: cardWidth,
                  child: _DiscoverCard(
                    media: result.items[index],
                    rank: ranked ? index + 1 : null,
                    heroTag: '${sectionKey}_$index',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiscoverCard extends ConsumerWidget {
  const _DiscoverCard({
    required this.media,
    required this.heroTag,
    this.rank,
  });

  final MediaModel media;
  final String heroTag;
  final int? rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inList = ref.watch(inWatchlistProvider(media.id));

    return MediaCard(
      title: media.displayTitle,
      imageUrl: media.coverImage,
      score: _localizedScore(context, media),
      meta: _countLabel(media),
      rank: rank,
      heroTag: heroTag,
      inList: inList,
      onTap: () => _openDetail(context, media, heroTag),
      onAction: () {
        final user = ref.read(authProvider).whenOrNull(data: (a) => a.user);
        openWatchlistSheet(context, ref, anime: media, user: user);
      },
    );
  }
}

class _RailSkeleton extends StatelessWidget {
  const _RailSkeleton({required this.cardWidth});

  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget bar(double width) => Container(
          height: 11,
          width: width,
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
      itemBuilder: (_, _) => SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.cover),
                ),
              ),
            ),
            const SizedBox(height: 8),
            bar(cardWidth * 0.8),
            const SizedBox(height: 6),
            bar(cardWidth * 0.4),
          ],
        ),
      ),
    );
  }
}

class _RailError extends StatelessWidget {
  const _RailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: c.text3, size: 30),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'discover_rail_error'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'action_retry'.tr(),
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
