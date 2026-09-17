import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/router/app_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/domain/reco_feed.dart';
import 'package:nextarc/features/recommendations/domain/reco_providers.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Largeur des jaquettes dans les rails.
const double _railCardWidth = 118;

/// Note AniList formatée selon la langue (« 8,4 » en FR/ES, « 8.4 » en EN).
String? _score(BuildContext context, MediaModel media) {
  final score = media.formattedScore;
  if (score == null) return null;
  return context.locale.languageCode == 'en'
      ? score
      : score.replaceAll('.', ',');
}

/// Note de l'utilisateur (« 10 », « 8,5 »).
String _userScore(BuildContext context, double score) {
  final raw = score.toStringAsFixed(score % 1 == 0 ? 0 : 1);
  return context.locale.languageCode == 'en' ? raw : raw.replaceAll('.', ',');
}

String? _countLabel(MediaModel media) {
  if (media.isManga) {
    return media.chapters == null
        ? null
        : 'meta_chapters'.tr(namedArgs: {'count': '${media.chapters}'});
  }
  return media.episodes == null
      ? null
      : 'meta_episodes'.tr(namedArgs: {'count': '${media.episodes}'});
}

String _reasonLabel(RecoSource source) =>
    (source.kind == RecoSourceKind.favourite
            ? 'reco_because_liked'
            : 'reco_because_rated')
        .tr(namedArgs: {'title': source.title});

void _openDetail(BuildContext context, MediaModel media, String heroTag) {
  context.push(
    '/detail/${media.id}',
    extra: {'heroTag': heroTag, 'coverUrl': media.coverImage},
  );
}

void _openSheet(BuildContext context, WidgetRef ref, MediaModel media) {
  final user = ref.read(authProvider).whenOrNull(data: (a) => a.user);
  openWatchlistSheet(context, ref, anime: media, user: user);
}

/// Écran « Pour toi » : recommandations anime / manga en rails.
class RecommendationsScreen extends ConsumerStatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  ConsumerState<RecommendationsScreen> createState() =>
      _RecommendationsScreenState();
}

class _RecommendationsScreenState extends ConsumerState<RecommendationsScreen> {
  late bool _isManga = ref.read(contentPreferenceProvider) == 'MANGA';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête (même gabarit que Ma liste) ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xs,
                AppSpacing.screen - 4,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'nav_for_you'.tr(),
                      style: text.headlineMedium?.copyWith(color: c.text1),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'search_hint'.tr(),
                    onTap: () => context.push(AppRoutes.search),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: SegmentedControl<bool>(
                segments: const [
                  (value: false, label: 'Anime'),
                  (value: true, label: 'Manga'),
                ],
                selected: _isManga,
                onChanged: (v) => setState(() => _isManga = v),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.transition,
                child: _isManga
                    ? const _RecoTab(key: ValueKey('manga'), isManga: true)
                    : const _RecoTab(key: ValueKey('anime'), isManga: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onglet ────────────────────────────────────────────────────────────────────

class _RecoTab extends ConsumerWidget {
  const _RecoTab({super.key, required this.isManga});

  final bool isManga;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = isManga
        ? mangaRecommendationsProvider
        : recommendationsProvider;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ref
        .watch(provider)
        .when(
          loading: () => const _RecoSkeleton(),
          error: (_, _) => _RecoError(onRetry: () => ref.invalidate(provider)),
          data: (feed) {
            final prefix = isManga ? 'm' : 'a';
            final children = feed.isPersonalised
                ? [
                    if (feed.pick case final pick?)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screen,
                        ),
                        child: _PickCard(pick: pick, heroTag: 'pick_$prefix'),
                      ),
                    for (final (i, rail) in feed.rails.indexed)
                      _Rail(
                        header: _SourceHeader(
                          source: rail.source,
                          count: rail.items.length,
                        ),
                        items: rail.items,
                        heroPrefix: 'reco_${prefix}_$i',
                      ),
                    if (feed.genreItems.isNotEmpty)
                      _Rail(
                        header: _GenresHeader(genres: feed.genres),
                        items: feed.genreItems,
                        heroPrefix: 'genres_$prefix',
                      ),
                  ]
                : [_TrendingSection(isManga: isManga, items: feed.trending)];

            return RefreshIndicator(
              onRefresh: () => ref.refresh(provider.future),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  0,
                  AppSpacing.sm,
                  0,
                  AppSpacing.xl + bottomInset,
                ),
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(height: 22),
                itemBuilder: (_, index) => children[index],
              ),
            );
          },
        );
  }
}

// ── Reco du jour ──────────────────────────────────────────────────────────────

class _PickCard extends ConsumerWidget {
  const _PickCard({required this.pick, required this.heroTag});

  final RecoPick pick;
  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final media = pick.media;
    final inList = ref.watch(inWatchlistProvider(media.id));
    final score = _score(context, media);
    final meta = [
      ?_countLabel(media),
      if (media.genres?.isNotEmpty == true) media.genres!.first,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.accent.withValues(alpha: 0.2),
              c.violet.withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(color: c.accent.withValues(alpha: 0.34)),
        ),
        child: InkWell(
          onTap: () => _openDetail(context, media, heroTag),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: MediaCover(
                    imageUrl: media.coverImage,
                    radius: 9,
                    heroTag: heroTag,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reco_pick_overline'.tr().toUpperCase(),
                        style: AppTypography.overline(c.accentText),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        media.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (score != null)
                              TextSpan(
                                text: '★ $score',
                                style: TextStyle(
                                  color: c.star,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (score != null && meta.isNotEmpty)
                              const TextSpan(text: ' · '),
                            TextSpan(text: meta),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: c.text2),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _SourceIcon(source: pick.source, small: true),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _reasonLabel(pick.source),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color:
                                    pick.source.kind == RecoSourceKind.favourite
                                    ? c.favourite
                                    : c.star,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _AddButton(
                  inList: inList,
                  size: 40,
                  onTap: () => _openSheet(context, ref, media),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.inList,
    required this.size,
    required this.onTap,
  });

  final bool inList;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: inList ? 'detail_edit'.tr() : 'detail_add_to_watchlist'.tr(),
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.minTouch,
          height: AppSpacing.minTouch,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: inList ? null : c.accentGradient,
                color: inList ? c.surface2 : null,
              ),
              child: Icon(
                inList ? Icons.check_rounded : Icons.add_rounded,
                size: 20,
                color: inList ? c.statusCurrent : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rails ─────────────────────────────────────────────────────────────────────

class _SourceIcon extends StatelessWidget {
  const _SourceIcon({required this.source, this.small = false});

  final RecoSource source;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (source.kind == RecoSourceKind.favourite) {
      return Icon(
        Icons.favorite_rounded,
        size: small ? 11 : 14,
        color: c.favourite,
      );
    }
    return Text(
      '★ ${_userScore(context, source.score ?? 0)}',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: c.star,
        fontSize: small ? 10 : 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// En-tête « icône de source + titre h2 + compteur ».
class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(color: c.text1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          style: text.labelMedium?.copyWith(
            color: c.accentText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader({required this.source, required this.count});

  final RecoSource source;
  final int count;

  @override
  Widget build(BuildContext context) => _RailHeader(
    leading: _SourceIcon(source: source),
    title: _reasonLabel(source),
    trailing: '$count',
  );
}

class _GenresHeader extends StatelessWidget {
  const _GenresHeader({required this.genres});

  final List<String> genres;

  @override
  Widget build(BuildContext context) => _RailHeader(
    leading: Icon(
      Icons.auto_awesome_rounded,
      size: 14,
      color: AppColors.of(context).accentText,
    ),
    title: 'reco_in_your_genres'.tr(),
    trailing: genres.join(' · '),
  );
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.header,
    required this.items,
    required this.heroPrefix,
  });

  final Widget header;
  final List<MediaModel> items;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: header,
        ),
        const SizedBox(height: 10),
        SizedBox(
          // jaquette 2:3 + titre sur 2 lignes + ligne de méta
          height: _railCardWidth * 1.5 + 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: _railCardWidth,
              child: _RailCard(
                media: items[index],
                heroTag: '${heroPrefix}_$index',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailCard extends ConsumerWidget {
  const _RailCard({required this.media, required this.heroTag});

  final MediaModel media;
  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaCard(
      title: media.displayTitle,
      imageUrl: media.coverImage,
      score: _score(context, media),
      meta: _countLabel(media),
      heroTag: heroTag,
      inList: ref.watch(inWatchlistProvider(media.id)),
      onTap: () => _openDetail(context, media, heroTag),
      onAction: () => _openSheet(context, ref, media),
    );
  }
}

// ── État vide : aide + tendances ──────────────────────────────────────────────

class _TrendingSection extends ConsumerWidget {
  const _TrendingSection({required this.isManga, required this.items});

  final bool isManga;
  final List<MediaModel> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    void explore() {
      ref.read(browseFilterProvider.notifier).state = FilterParams(
        mediaType: isManga ? 'MANGA' : 'ANIME',
        sort: 'TRENDING_DESC',
      );
      context.push(AppRoutes.browse);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.accent.withValues(alpha: 0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_rounded, size: 15, color: c.favourite),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        (isManga
                                ? 'reco_empty_title_manga'
                                : 'reco_empty_title_anime')
                            .tr(),
                        style: text.titleSmall?.copyWith(color: c.text1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  (isManga ? 'reco_empty_body_manga' : 'reco_empty_body_anime')
                      .tr(),
                  style: text.bodySmall?.copyWith(color: c.text2, height: 1.5),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: (isManga ? 'reco_explore_manga' : 'reco_explore_anime')
                      .tr(),
                  onPressed: explore,
                ),
              ],
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHeader(
              title:
                  (isManga
                          ? 'discover_trending_manga'
                          : 'discover_trending_anime')
                      .tr(),
              actionLabel: 'discover_see_all'.tr(),
              onAction: explore,
            ),
            const SizedBox(height: 10),
            for (final (i, media) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _TrendingRow(
                media: media,
                rank: i + 1,
                heroTag: 'reco_trend_${isManga ? 'm' : 'a'}_$i',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TrendingRow extends ConsumerWidget {
  const _TrendingRow({
    required this.media,
    required this.rank,
    required this.heroTag,
  });

  final MediaModel media;
  final int rank;
  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final score = _score(context, media);
    final meta = [
      ?_countLabel(media),
      if (media.genres?.isNotEmpty == true) media.genres!.first,
    ].join(' · ');

    return Material(
      color: c.surface1,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context, media, heroTag),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(11, 11, 4, 11),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: text.titleMedium?.copyWith(
                    color: c.text3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: MediaCover(
                  imageUrl: media.coverImage,
                  radius: 9,
                  heroTag: heroTag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(color: c.text1),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (score != null)
                            TextSpan(
                              text: '★ $score',
                              style: TextStyle(
                                color: c.star,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (score != null && meta.isNotEmpty)
                            const TextSpan(text: ' · '),
                          TextSpan(text: meta),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: c.text2),
                    ),
                  ],
                ),
              ),
              _AddButton(
                inList: ref.watch(inWatchlistProvider(media.id)),
                size: 34,
                onTap: () => _openSheet(context, ref, media),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chargement et erreur ──────────────────────────────────────────────────────

class _RecoSkeleton extends StatelessWidget {
  const _RecoSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget block({double? width, required double height, double radius = 12}) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        0,
        AppSpacing.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.screen),
          child: block(height: 100, radius: 16),
        ),
        for (var rail = 0; rail < 2; rail++) ...[
          const SizedBox(height: 22),
          block(width: 200, height: 14, radius: 4),
          const SizedBox(height: 10),
          SizedBox(
            height: _railCardWidth * 1.5,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  block(width: _railCardWidth, height: _railCardWidth * 1.5),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecoError extends StatelessWidget {
  const _RecoError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: c.text3),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'search_offline_title'.tr(),
              style: text.titleMedium?.copyWith(color: c.text1),
            ),
            const SizedBox(height: 6),
            Text(
              'reco_offline_body'.tr(),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: c.text2),
            ),
            const SizedBox(height: AppSpacing.md),
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
