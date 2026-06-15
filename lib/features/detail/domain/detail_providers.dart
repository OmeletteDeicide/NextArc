import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/detail/data/detail_queries.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Provider paramétré par l'id de l'anime.
final animeDetailProvider =
    FutureProvider.family<MediaModel, int>((ref, id) async {
  final client = AnilistClient.instance;

  final result = await client.query(
    QueryOptions(
      document: gql(DetailQueries.animeDetail),
      variables: {'id': id},
    ),
  );

  if (result.hasException) {
    throw Exception('Impossible de charger l\'anime #$id');
  }

  final data = result.data?['Media'] as Map<String, dynamic>?;
  if (data == null) throw Exception('Anime introuvable');

  return MediaModel.fromJson(data);
});

/// Retourne l'entrée AniList de l'utilisateur pour un anime donné (ou null).
final userListEntryProvider =
    Provider.family<MediaListEntry?, int>((ref, animeId) {
  final listAsync = ref.watch(userListProvider);

  return listAsync.whenOrNull(
    data: (groups) {
      for (final group in groups) {
        for (final entry in group.entries) {
          if (entry.media.id == animeId) return entry;
        }
      }
      return null;
    },
  );
});

/// Retourne l'entrée locale invité pour un anime donné (ou null).
final guestListEntryProvider =
    Provider.family<GuestWatchlistEntry?, int>((ref, animeId) {
  final listAsync = ref.watch(guestWatchlistProvider);

  return listAsync.whenOrNull(
    data: (entries) =>
        entries.where((e) => e.animeId == animeId).firstOrNull,
  );
});
