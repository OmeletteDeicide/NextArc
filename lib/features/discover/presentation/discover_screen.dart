import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nextarc/core/widgets/horizontal_anime_list.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/presentation/watchlist_sheet_helper.dart';

String? _coverUrl(AsyncValue asyncValue, String tag) {
  final index = int.tryParse(tag.split('_').last);
  if (index == null) return null;
  return asyncValue.whenOrNull(
    data: (result) => result.items.length > index
        ? result.items[index].coverImage
        : null,
  );
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

    final isLoggedIn = ref.watch(authProvider).whenOrNull(
              data: (a) => a.isAuthenticated,
            ) ??
        false;

    void openWatchlist(MediaModel media) =>
        openWatchlistSheet(context, ref, anime: media, isLoggedIn: isLoggedIn);

    final animeSliders = [
      HorizontalAnimeList(
        title: 'Tendances anime',
        asyncValue: trending,
        sectionKey: 'trending',
        onAnimeTap: (id, tag) => context.push('/detail/$id',
            extra: {'heroTag': tag, 'coverUrl': _coverUrl(trending, tag)}),
        onRetry: () => ref.invalidate(trendingAnimeProvider),
        onWatchlistTap: openWatchlist,
      ),
      HorizontalAnimeList(
        title: 'En ce moment',
        asyncValue: seasonal,
        sectionKey: 'seasonal',
        onAnimeTap: (id, tag) => context.push('/detail/$id',
            extra: {'heroTag': tag, 'coverUrl': _coverUrl(seasonal, tag)}),
        onRetry: () => ref.invalidate(seasonalAnimeProvider),
        onWatchlistTap: openWatchlist,
      ),
    ];

    final mangaSliders = [
      HorizontalAnimeList(
        title: 'Tendances manga',
        asyncValue: trendingManga,
        sectionKey: 'trending_manga',
        onAnimeTap: (id, tag) => context.push('/detail/$id',
            extra: {'heroTag': tag, 'coverUrl': _coverUrl(trendingManga, tag)}),
        onRetry: () => ref.invalidate(trendingMangaProvider),
        onWatchlistTap: openWatchlist,
      ),
      HorizontalAnimeList(
        title: 'En cours de publication',
        asyncValue: releasingManga,
        sectionKey: 'releasing_manga',
        onAnimeTap: (id, tag) => context.push('/detail/$id',
            extra: {
              'heroTag': tag,
              'coverUrl': _coverUrl(releasingManga, tag),
            }),
        onRetry: () => ref.invalidate(releasingMangaProvider),
        onWatchlistTap: openWatchlist,
      ),
    ];

    // Ordre dynamique : manga d'abord si l'utilisateur a plus de manga
    final sections = preference == 'MANGA'
        ? [...mangaSliders, ...animeSliders]
        : [...animeSliders, ...mangaSliders];

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
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
        child: ListView(
          children: [
            ...sections,
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
