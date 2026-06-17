import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/data/watchlist_queries.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

class WatchlistRepository {
  // ── Liste par statut ───────────────────────────────────────────────────────

  Future<List<MediaListGroup>> getUserList(int userId) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(WatchlistQueries.mediaListCollection),
        variables: {'userId': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw Exception('Impossible de charger ta liste : ${result.exception}');
    }

    final collection = result.data?['MediaListCollection']
        as Map<String, dynamic>?;
    if (collection == null) return [];

    final rawLists = collection['lists'] as List<dynamic>;
    final groups = <MediaListGroup>[];

    // Ordre d'affichage souhaité
    const orderedStatuses = [
      ListStatus.current,
      ListStatus.completed,
      ListStatus.planning,
      ListStatus.paused,
      ListStatus.dropped,
    ];

    for (final targetStatus in orderedStatuses) {
      // AniList peut retourner plusieurs listes avec le même statut — on les fusionne
      final matchingLists = rawLists.where((l) {
        final s = (l as Map<String, dynamic>)['status'] as String?;
        return s == targetStatus.anilistValue;
      }).toList();

      if (matchingLists.isEmpty) continue;

      final entries = <MediaListEntry>[];
      for (final list in matchingLists) {
        final rawEntries = (list as Map<String, dynamic>)['entries']
            as List<dynamic>;
        entries.addAll(
          rawEntries.map(
            (e) => MediaListEntry.fromJson(e as Map<String, dynamic>),
          ),
        );
      }

      if (entries.isNotEmpty) {
        groups.add(MediaListGroup(status: targetStatus, entries: entries));
      }
    }

    return groups;
  }

  // ── Liste manga par statut ─────────────────────────────────────────────────

  Future<List<MediaListGroup>> getUserMangaList(int userId) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(WatchlistQueries.mangaListCollection),
        variables: {'userId': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw Exception('Impossible de charger ta liste manga : ${result.exception}');
    }

    final collection = result.data?['MediaListCollection']
        as Map<String, dynamic>?;
    if (collection == null) return [];

    final rawLists = collection['lists'] as List<dynamic>;
    final groups = <MediaListGroup>[];

    const orderedStatuses = [
      ListStatus.current,
      ListStatus.completed,
      ListStatus.planning,
      ListStatus.paused,
      ListStatus.dropped,
    ];

    for (final targetStatus in orderedStatuses) {
      final matchingLists = rawLists.where((l) {
        final s = (l as Map<String, dynamic>)['status'] as String?;
        return s == targetStatus.anilistValue;
      }).toList();

      if (matchingLists.isEmpty) continue;

      final entries = <MediaListEntry>[];
      for (final list in matchingLists) {
        final rawEntries = (list as Map<String, dynamic>)['entries']
            as List<dynamic>;
        entries.addAll(
          rawEntries.map(
            (e) => MediaListEntry.fromJson(e as Map<String, dynamic>),
          ),
        );
      }

      if (entries.isNotEmpty) {
        groups.add(MediaListGroup(status: targetStatus, entries: entries));
      }
    }

    return groups;
  }

  // ── Favoris ────────────────────────────────────────────────────────────────

  Future<List<MediaModel>> getUserFavourites(int userId) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(WatchlistQueries.userFavourites),
        variables: {'userId': userId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      throw Exception('Impossible de charger tes favoris : ${result.exception}');
    }

    final user = result.data?['User'] as Map<String, dynamic>?;
    final animeNodes = user?['favourites']?['anime']?['nodes']
        as List<dynamic>?;

    if (animeNodes == null) return [];

    return animeNodes
        .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
