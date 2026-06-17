import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/recommendations/data/reco_repository.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

final recoRepositoryProvider = Provider((_) => RecoRepository());

/// Recommandations anime personnalisées ou tendances en fallback.
final recommendationsProvider =
    FutureProvider<List<RecommendationItem>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final repo = ref.read(recoRepositoryProvider);

  if (auth.isAuthenticated) {
    final groups = await ref.watch(userListProvider.future);
    final favs = await ref.watch(userFavouritesProvider.future);

    final seenIds = <int>{};
    for (final group in groups) {
      if (group.status == ListStatus.completed ||
          group.status == ListStatus.dropped) {
        for (final e in group.entries) {
          seenIds.add(e.media.id);
        }
      }
    }

    final sources = <({int id, String title})>[];

    for (final fav in favs.take(3)) {
      sources.add((id: fav.id, title: fav.displayTitle));
    }

    for (final group in groups) {
      for (final entry in group.entries) {
        if ((entry.score ?? 0) >= 7 &&
            !sources.any((s) => s.id == entry.media.id)) {
          sources.add((id: entry.media.id, title: entry.media.displayTitle));
        }
      }
    }

    if (sources.isNotEmpty) {
      final allRecos = <RecommendationItem>[];
      final seenRecoIds = <int>{...seenIds};

      for (final source in sources.take(5)) {
        final recos = await repo.getRecommendationsForAnime(
          animeId: source.id,
          sourceTitle: source.title,
          excludeIds: seenRecoIds,
        );

        for (final reco in recos) {
          if (!seenRecoIds.contains(reco.recommended.id)) {
            allRecos.add(reco);
            seenRecoIds.add(reco.recommended.id);
          }
        }
      }

      if (allRecos.isNotEmpty) return allRecos;
    }
  }

  final animeRepo = ref.read(animeRepositoryProvider);
  final trending = await animeRepo.getTrending(perPage: 20);

  return trending.items
      .map((anime) => RecommendationItem(sourceTitle: '', recommended: anime))
      .toList();
});

/// Recommandations manga personnalisées ou tendances manga en fallback.
final mangaRecommendationsProvider =
    FutureProvider<List<RecommendationItem>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final repo = ref.read(recoRepositoryProvider);

  if (auth.isAuthenticated) {
    final groups = await ref.watch(userMangaListProvider.future);

    final seenIds = <int>{};
    for (final group in groups) {
      if (group.status == ListStatus.completed ||
          group.status == ListStatus.dropped) {
        for (final e in group.entries) {
          seenIds.add(e.media.id);
        }
      }
    }

    final sources = <({int id, String title})>[];
    for (final group in groups) {
      for (final entry in group.entries) {
        if ((entry.score ?? 0) >= 7 &&
            !sources.any((s) => s.id == entry.media.id)) {
          sources.add((id: entry.media.id, title: entry.media.displayTitle));
        }
      }
    }

    if (sources.isNotEmpty) {
      final allRecos = <RecommendationItem>[];
      final seenRecoIds = <int>{...seenIds};

      for (final source in sources.take(5)) {
        final recos = await repo.getRecommendationsForAnime(
          animeId: source.id,
          sourceTitle: source.title,
          excludeIds: seenRecoIds,
        );

        for (final reco in recos) {
          if (!seenRecoIds.contains(reco.recommended.id)) {
            allRecos.add(reco);
            seenRecoIds.add(reco.recommended.id);
          }
        }
      }

      if (allRecos.isNotEmpty) return allRecos;
    }
  }

  // Fallback : tendances manga
  final animeRepo = ref.read(animeRepositoryProvider);
  final trending = await animeRepo.getTrendingManga(perPage: 20);

  return trending.items
      .map((manga) => RecommendationItem(sourceTitle: '', recommended: manga))
      .toList();
});

/// Indique si les recos anime viennent du compte perso.
final recoIsPersonalisedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.whenOrNull(data: (a) => a.isAuthenticated) ?? false;
});
