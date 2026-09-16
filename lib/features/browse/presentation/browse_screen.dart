import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/widgets/ds/ds.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/browse/domain/active_filters.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/browse/presentation/filter_sheet.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

/// Explorer : tout le catalogue AniList, filtré et trié.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _scrollController = ScrollController();

  // État de pagination local
  final _items = <MediaModel>[];
  int _page = 1;
  int? _total;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  FilterParams get _params => ref.read(browseFilterProvider);

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_loadingMore &&
        _hasMore &&
        !_initialLoading) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore && !reset) return;

    if (reset) {
      setState(() {
        _items.clear();
        _page = 1;
        _total = null;
        _hasMore = true;
        _initialLoading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final params = _params;
      final result = await ref.read(
        filteredBrowseProvider((params: params, page: _page)).future,
      );

      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _total ??= result.total;
        _hasMore = result.hasNextPage;
        _page++;
        _initialLoading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
        _loadingMore = false;
      });
    }
  }

  void _apply(FilterParams params) {
    ref.read(browseFilterProvider.notifier).state = params;
    HapticFeedback.lightImpact();
    _load(reset: true);
  }

  Future<void> _openFilters() async {
    final result = await showFilterSheet(context, current: _params);
    if (result != null && mounted) _apply(result);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final params = ref.watch(browseFilterProvider);
    final active = activeFiltersOf(params);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen - 4, AppSpacing.xs, AppSpacing.screen - 4, 0),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('browse_title'.tr(),
                        style: text.headlineSmall
                            ?.copyWith(fontSize: 19, color: c.text1)),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RoundIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'browse_filters'.tr(),
                        color: c.accentText,
                        onTap: _openFilters,
                      ),
                      if (active.isNotEmpty)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IgnorePointer(
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 17, minHeight: 17),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: c.accentGradient,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${active.length}',
                                style: text.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Barre d'état + chips actives ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
              child: FilterStatusBar(
                resultLabel: _total == null
                    ? (_initialLoading ? null : '')
                    : resultCountLabel(context, _total!),
                filterCount: active.length,
                onReset: () =>
                    _apply(FilterParams(mediaType: params.mediaType, sort: params.sort)),
              ),
            ),
            if (active.isNotEmpty)
              SizedBox(
                height: AppSpacing.minTouch,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                  scrollDirection: Axis.horizontal,
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActiveFilterChip(
                    label: activeFilterLabel(active[i]),
                    onRemove: () => _apply(active[i].remove(params)),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),

            // ── Contenu ─────────────────────────────────────────────────────
            Expanded(child: _buildBody(params)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FilterParams params) {
    if (_initialLoading) return const _GridSkeleton();

    if (_error != null && _items.isEmpty) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'browse_error_title'.tr(),
        body: 'browse_error_body'.tr(),
        primaryLabel: 'action_retry'.tr(),
        onPrimary: () => _load(reset: true),
      );
    }

    if (_items.isEmpty) {
      final relax = filterToRelax(params);
      final count = activeFilterCount(params);
      return _EmptyState(
        icon: Icons.tune_rounded,
        title: 'browse_empty_title'.tr(),
        body: relax == null
            ? 'browse_empty'.tr()
            : 'browse_empty_body'.tr(namedArgs: {
                'filters': filterCountLabel(count),
                'filter': activeFilterLabel(relax),
              }),
        primaryLabel: relax == null
            ? null
            : 'browse_remove_filter'
                .tr(namedArgs: {'filter': activeFilterLabel(relax)}),
        onPrimary: relax == null ? null : () => _apply(relax.remove(params)),
        secondaryLabel: count > 0 ? 'browse_clear_filters'.tr() : null,
        onSecondary: () => _apply(
            FilterParams(mediaType: params.mediaType, sort: params.sort)),
      );
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - AppSpacing.screen * 2 - spacing) / 2;
        // Jaquette 2:3 + titre sur 2 lignes + note
        final extent = cardWidth * 1.5 + 72;

        return GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs,
              AppSpacing.screen, AppSpacing.xl + bottomInset),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: extent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length + (_hasMore ? 2 : 0),
          itemBuilder: (context, i) {
            if (i >= _items.length) return const _CardSkeleton();
            return _BrowseCard(media: _items[i], index: i);
          },
        );
      },
    );
  }
}

class _BrowseCard extends ConsumerWidget {
  const _BrowseCard({required this.media, required this.index});

  final MediaModel media;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inList = ref.watch(inWatchlistProvider(media.id));
    final heroTag = 'browse_${media.id}_$index';
    final score = media.formattedScore == null
        ? null
        : context.locale.languageCode == 'en'
            ? media.formattedScore
            : media.formattedScore!.replaceAll('.', ',');
    final count = media.isManga
        ? (media.chapters == null
            ? null
            : 'meta_chapters'.tr(namedArgs: {'count': '${media.chapters}'}))
        : (media.episodes == null
            ? null
            : 'meta_episodes'.tr(namedArgs: {'count': '${media.episodes}'}));

    return MediaCard(
      title: media.displayTitle,
      imageUrl: media.coverImage,
      score: score,
      meta: count,
      heroTag: heroTag,
      inList: inList,
      onTap: () => context.push('/detail/${media.id}',
          extra: {'heroTag': heroTag, 'coverUrl': media.coverImage}),
      onAction: () {
        final user = ref.read(authProvider).valueOrNull?.user;
        openWatchlistSheet(context, ref, anime: media, user: user);
      },
    );
  }
}

// ── Squelettes (jamais de spinner sur une grille) ─────────────────────────────

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final cardWidth =
            (constraints.maxWidth - AppSpacing.screen * 2 - spacing) / 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, 0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: cardWidth * 1.5 + 72,
            crossAxisSpacing: spacing,
            mainAxisSpacing: 16,
          ),
          itemCount: 4,
          itemBuilder: (_, _) => const _CardSkeleton(),
        );
      },
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget bar(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 11,
            decoration: BoxDecoration(
              color: c.surface1,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        );
    return Column(
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
        const SizedBox(height: 7),
        bar(0.9),
        const SizedBox(height: 6),
        bar(0.55),
      ],
    );
  }
}

// ── États vide / erreur ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: c.surface1,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, size: 26, color: c.text3),
            ),
            const SizedBox(height: 13),
            Text(title,
                textAlign: TextAlign.center,
                style: text.headlineSmall
                    ?.copyWith(fontSize: 16, color: c.text1)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: c.text2, height: 1.55)),
            if (primaryLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: primaryLabel!,
                expand: true,
                onPressed: onPrimary,
              ),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: secondaryLabel!,
                variant: AppButtonVariant.secondary,
                expand: true,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
