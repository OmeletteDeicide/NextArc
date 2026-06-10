import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/recommendations/data/reco_repository.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

final recoRepositoryProvider = Provider((_) => RecoRepository());

/// Provider principal des recommandations.
///
/// Logique :
/// 1. Si connecté : prend les anime notés ≥7 ou les favoris (max 5 sources)
///    et agrège leurs recommandations, en excluant ce que l'utilisateur a déjà vu.
/// 2. Si non connecté ou pas assez de données : fallback sur les tendances.
final recommendationsProvider =
    FutureProvider<List<RecommendationItem>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  final repo = ref.read(recoRepositoryProvider);

  // ── Utilisateur connecté ─────────────────────────────────────────────────
  if (auth.isAuthenticated) {
    final groups = await ref.watch(userListProvider.future);
    final favs = await ref.watch(userFavouritesProvider.future);

    // IDs des anime déjà vus (COMPLETED ou DROPPED) → à exclure des recos
    final seenIds = <int>{};
    for (final group in groups) {
      if (group.status == ListStatus.completed ||
          group.status == ListStatus.dropped) {
        for (final e in group.entries) {
          seenIds.add(e.media.id);
        }
      }
    }

    // Sources : favoris + anime notés ≥7 (triés par score desc, max 5)
    final sources = <({int id, String title})>[];

    for (final fav in favs.take(3)) {
      sources.add((id: fav.id, title: fav.displayTitle));
    }

    for (final group in groups) {
      for (final entry in group.entries) {
        if ((entry.score ?? 0) >= 7 &&
            !sources.any((s) => s.id == entry.media.id)) {
          sources.add((
            id: entry.media.id,
            title: entry.media.displayTitle,
          ));
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
          // Déduplique : même anime recommandé depuis plusieurs sources
          if (!seenRecoIds.contains(reco.recommended.id)) {
            allRecos.add(reco);
            seenRecoIds.add(reco.recommended.id);
          }
        }
      }

      if (allRecos.isNotEmpty) return allRecos;
    }
  }

  // ── Fallback : tendances ─────────────────────────────────────────────────
  final animeRepo = ref.read(animeRepositoryProvider);
  final trending = await animeRepo.getTrending(perPage: 20);

  return trending.items
      .map((anime) => RecommendationItem(
            sourceTitle: '',
            recommended: anime,
          ))
      .toList();
});

/// Indique si les recos viennent du compte perso ou du fallback tendances.
final recoIsPersonalisedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.whenOrNull(data: (a) => a.isAuthenticated) ?? false;
});
