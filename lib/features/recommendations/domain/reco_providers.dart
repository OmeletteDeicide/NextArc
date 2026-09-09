import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/recommendations/data/reco_repository.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

final recoRepositoryProvider = Provider((_) => RecoRepository());

/// Recommandations anime personnalisées ou tendances en fallback.
final recommendationsProvider =
    FutureProvider<List<RecommendationItem>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final repo = ref.read(recoRepositoryProvider);

  if (auth.user?.hasAnilist == true) {
    final groups = await ref.watch(userListProvider.future);
    final favs = await ref.watch(userFavouritesProvider.future);

    // Exclure TOUS les éléments de la watchlist (pas seulement terminés/abandonnés)
    final seenIds = <int>{};
    for (final group in groups) {
      for (final e in group.entries) {
        seenIds.add(e.media.id);
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
      // Récupérer max 3 recos par source (interleave pour diversifier)
      const maxPerSource = 3;
      final seenRecoIds = <int>{...seenIds};
      final perSource = <List<RecommendationItem>>[];

      for (final source in sources.take(5)) {
        final recos = await repo.getRecommendationsForAnime(
          animeId: source.id,
          sourceTitle: source.title,
          excludeIds: seenRecoIds,
        );
        final picked = <RecommendationItem>[];
        for (final reco in recos) {
          if (!seenRecoIds.contains(reco.recommended.id)) {
            picked.add(reco);
            seenRecoIds.add(reco.recommended.id);
            if (picked.length >= maxPerSource) break;
          }
        }
        if (picked.isNotEmpty) perSource.add(picked);
      }

      // Interleave : 1 reco de chaque source à tour de rôle
      final allRecos = <RecommendationItem>[];
      final maxRound = perSource.fold(0, (m, l) => l.length > m ? l.length : m);
      for (var i = 0; i < maxRound; i++) {
        for (final list in perSource) {
          if (i < list.length) allRecos.add(list[i]);
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

  if (auth.user?.hasAnilist == true) {
    final groups = await ref.watch(userMangaListProvider.future);

    // Exclure TOUS les éléments de la watchlist manga
    final seenIds = <int>{};
    for (final group in groups) {
      for (final e in group.entries) {
        seenIds.add(e.media.id);
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
      const maxPerSource = 3;
      final seenRecoIds = <int>{...seenIds};
      final perSource = <List<RecommendationItem>>[];

      for (final source in sources.take(5)) {
        final recos = await repo.getRecommendationsForAnime(
          animeId: source.id,
          sourceTitle: source.title,
          excludeIds: seenRecoIds,
        );
        final picked = <RecommendationItem>[];
        for (final reco in recos) {
          if (!seenRecoIds.contains(reco.recommended.id)) {
            picked.add(reco);
            seenRecoIds.add(reco.recommended.id);
            if (picked.length >= maxPerSource) break;
          }
        }
        if (picked.isNotEmpty) perSource.add(picked);
      }

      final allRecos = <RecommendationItem>[];
      final maxRound = perSource.fold(0, (m, l) => l.length > m ? l.length : m);
      for (var i = 0; i < maxRound; i++) {
        for (final list in perSource) {
          if (i < list.length) allRecos.add(list[i]);
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

/// Indique si les recos anime viennent du compte AniList perso.
final recoIsPersonalisedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.whenOrNull(data: (a) => a.user?.hasAnilist == true) ?? false;
});
