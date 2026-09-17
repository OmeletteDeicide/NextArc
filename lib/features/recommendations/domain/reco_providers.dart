import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/data/reco_repository.dart';
import 'package:nextarc/features/recommendations/domain/reco_feed.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

final recoRepositoryProvider = Provider((_) => RecoRepository());

/// « Pour toi » anime : rails personnalisés ou tendances en attendant.
final recommendationsProvider = FutureProvider<RecoFeed>(
  (ref) => _buildFeed(ref, isManga: false),
);

/// « Pour toi » manga.
final mangaRecommendationsProvider = FutureProvider<RecoFeed>(
  (ref) => _buildFeed(ref, isManga: true),
);

/// Note minimale pour qu'un titre serve de source.
const double _minSourceScore = 8;

Future<RecoFeed> _buildFeed(Ref ref, {required bool isManga}) async {
  final auth = await ref.watch(authProvider.future);
  final user = auth.user;

  final listIds = <int>{};
  final sources = <RecoSource>[];
  // Genres des titres terminés (ou aimés / bien notés à défaut)
  final completedGenres = <List<String>?>[];
  final likedGenres = <List<String>?>[];

  void consider({
    required int id,
    required String title,
    required bool favourite,
    required double? score,
    required ListStatus? status,
    required List<String>? genres,
  }) {
    listIds.add(id);
    if (status == ListStatus.completed) completedGenres.add(genres);
    if (favourite) {
      sources.add(
        RecoSource(
          id: id,
          title: title,
          kind: RecoSourceKind.favourite,
          score: score,
        ),
      );
      likedGenres.add(genres);
    } else if ((score ?? 0) >= _minSourceScore) {
      sources.add(
        RecoSource(
          id: id,
          title: title,
          kind: RecoSourceKind.rated,
          score: score,
        ),
      );
      likedGenres.add(genres);
    }
  }

  if (user?.usesAnilistList == true) {
    final groups = await ref.watch(
      (isManga ? userMangaListProvider : userListProvider).future,
    );
    // Les favoris AniList exposés par l'app ne concernent que l'anime
    final favIds = isManga
        ? const <int>{}
        : (await ref.watch(
            userFavouritesProvider.future,
          )).map((m) => m.id).toSet();
    for (final group in groups) {
      for (final entry in group.entries) {
        consider(
          id: entry.media.id,
          title: entry.media.displayTitle,
          favourite: favIds.contains(entry.media.id),
          score: entry.score,
          status: entry.status,
          genres: entry.media.genres,
        );
      }
    }
  } else {
    final entries = user?.hasFirebase == true
        ? await ref.watch(firestoreWatchlistProvider.future)
        : await ref.watch(guestWatchlistProvider.future);
    for (final e in entries.where((e) => e.isManga == isManga)) {
      consider(
        id: e.animeId,
        title: e.title,
        favourite: e.favourite,
        score: e.score,
        status: e.status,
        genres: e.genres,
      );
    }
  }

  final selected = selectRecoSources(
    sources,
    now: DateTime.now(),
    seed: user?.firebaseUid ?? '${user?.id ?? ''}',
  );
  final genres = dominantGenres(
    completedGenres.any((g) => g?.isNotEmpty == true)
        ? completedGenres
        : likedGenres,
  );

  final recoRepo = ref.read(recoRepositoryProvider);
  final animeRepo = ref.read(animeRepositoryProvider);
  final type = isManga ? 'MANGA' : 'ANIME';

  if (selected.isEmpty) {
    final trending = isManga
        ? await animeRepo.getTrendingManga(perPage: 12)
        : await animeRepo.getTrending(perPage: 12);
    return buildRecoFeed(
      sources: const [],
      recosBySource: const {},
      excludeIds: listIds,
      trending: trending.items,
    );
  }

  Future<List<MediaModel>> genrePool() async {
    if (genres.isEmpty) return const [];
    try {
      final result = await animeRepo.browseFiltered(
        params: FilterParams(
          mediaType: type,
          genres: genres,
          minScore: 7,
          sort: 'POPULARITY_DESC',
        ),
        perPage: 40,
      );
      return result.items;
    } catch (_) {
      // Rail facultatif : on n'échoue pas tout l'écran pour lui
      return const [];
    }
  }

  final results = await Future.wait([
    genrePool(),
    for (final source in selected) recoRepo.getRecommendations(source.id),
  ]);

  final feed = buildRecoFeed(
    sources: selected,
    recosBySource: {
      for (var i = 0; i < selected.length; i++) selected[i].id: results[i + 1],
    },
    excludeIds: listIds,
    genres: genres,
    genrePool: results.first,
  );
  if (feed.isPersonalised) return feed;

  // Sources sans recos exploitables : mêmes tendances que l'état vide
  final trending = isManga
      ? await animeRepo.getTrendingManga(perPage: 12)
      : await animeRepo.getTrending(perPage: 12);
  return buildRecoFeed(
    sources: const [],
    recosBySource: const {},
    excludeIds: listIds,
    trending: trending.items,
  );
}
