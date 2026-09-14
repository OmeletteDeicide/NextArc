import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/auth/domain/user_model.dart';
import 'package:nextarc/features/browse/domain/browse_provider.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/browse/presentation/filter_sheet.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

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
            _scrollController.position.maxScrollExtent - 300 &&
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

  void _openFilters() async {
    final current = ref.read(browseFilterProvider);
    final result = await showFilterSheet(context, current: current);
    if (result != null && mounted) {
      ref.read(browseFilterProvider.notifier).state = result;
      HapticFeedback.lightImpact();
      _load(reset: true);
    }
  }

  void _clearFilters() {
    ref.read(browseFilterProvider.notifier).state = const FilterParams();
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(browseFilterProvider);
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).whenOrNull<UserModel?>(
          data: (a) => a.user,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text('browse_title'.tr()),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'browse_filters'.tr(),
                onPressed: _openFilters,
              ),
              if (params.activeCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${params.activeCount}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtres actifs ─────────────────────────────────────────────
          if (!params.isEmpty)
            _ActiveFiltersBar(params: params, onClear: _clearFilters),

          // ── Contenu ────────────────────────────────────────────────────
          Expanded(
            child: _buildBody(params, user, cs),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(FilterParams params, UserModel? user, ColorScheme cs) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54))),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('action_retry'.tr()),
              onPressed: () => _load(reset: true),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('browse_empty'.tr(),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _openFilters,
              child: Text('browse_adjust_filters'.tr()),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      // +1 pour le loader en bas
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final media = _items[i];
        return _MediaCard(
          media: media,
          onTap: () => context.push(
            '/detail/${media.id}',
            extra: {'coverUrl': media.coverImage},
          ),
          onLongPress: () => openWatchlistSheet(
            context,
            ref,
            anime: media,
            user: user,
          ),
        );
      },
    );
  }
}

// ── Barre des filtres actifs ──────────────────────────────────────────────────

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({required this.params, required this.onClear});
  final FilterParams params;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <String>[];

    if (params.genres.isNotEmpty) chips.addAll(params.genres);
    if (params.formats.isNotEmpty) chips.addAll(params.formats);
    if (params.yearFrom != null || params.yearTo != null) {
      final from = params.yearFrom ?? '?';
      final to = params.yearTo ?? '?';
      chips.add('$from–$to');
    }
    if (params.minScore != null) chips.add('≥ ${params.minScore}/10');
    if (params.status != null) {
      chips.add(FilterParams.statusOptions
          .firstWhere((s) => s.value == params.status,
              orElse: () => (value: '', label: params.status!))
          .label);
    }

    return Container(
      height: 44,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => Chip(
                label: Text(chips[i],
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'browse_clear_filters'.tr(),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

// ── Carte média ───────────────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.media,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaModel media;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            media.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: media.coverImage!,
                    fit: BoxFit.cover,
                  )
                : Container(color: cs.surfaceContainerHighest),
            Positioned.fill(
              child: DecoratedBox(
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
            ),
            if (media.averageScore != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 10, color: Color(0xFFFFC107)),
                      const SizedBox(width: 2),
                      Text(
                        media.formattedScore ?? '',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                media.displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
