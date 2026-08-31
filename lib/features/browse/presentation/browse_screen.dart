import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
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
  FilterParams _params = const FilterParams();

  void _openFilters() async {
    final result = await showFilterSheet(context, current: _params);
    if (result != null && mounted) {
      setState(() => _params = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final browseAsync = ref.watch(filteredBrowseProvider(_params));
    final cs = Theme.of(context).colorScheme;
    final isLoggedIn = ref.watch(authProvider).whenOrNull(
              data: (a) => a.isAuthenticated,
            ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: Text('browse_title'.tr()),
        actions: [
          // Badge avec nombre de filtres actifs
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'browse_filters'.tr(),
                onPressed: _openFilters,
              ),
              if (_params.activeCount > 0)
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
                        '${_params.activeCount}',
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
          // ── Résumé des filtres actifs ───────────────────────────────────
          if (!_params.isEmpty)
            _ActiveFiltersBar(params: _params, onClear: () {
              setState(() => _params = const FilterParams());
            }),

          // ── Grille de résultats ────────────────────────────────────────
          Expanded(
            child: browseAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(e.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.54))),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: Text('action_retry'.tr()),
                      onPressed: () =>
                          ref.invalidate(filteredBrowseProvider(_params)),
                    ),
                  ],
                ),
              ),
              data: (result) {
                if (result.items.isEmpty) {
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
                                color:
                                    cs.onSurface.withValues(alpha: 0.45))),
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
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: result.items.length,
                  itemBuilder: (context, i) {
                    final media = result.items[i];
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
                        isLoggedIn: isLoggedIn,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
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
            // Jaquette
            media.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: media.coverImage!,
                    fit: BoxFit.cover,
                  )
                : Container(color: cs.surfaceContainerHighest),

            // Gradient bas
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

            // Score en haut à droite
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

            // Titre bas
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
                  shadows: [
                    Shadow(blurRadius: 4, color: Colors.black),
                  ],
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
