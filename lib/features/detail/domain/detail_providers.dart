import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/detail/data/detail_queries.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Provider paramétré par l'id du média (anime ou manga).
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
    throw Exception('Impossible de charger le média #$id');
  }

  final data = result.data?['Media'] as Map<String, dynamic>?;
  if (data == null) throw Exception('Média introuvable');

  return MediaModel.fromJson(data);
});

/// Retourne l'entrée AniList de l'utilisateur pour un média donné (anime ou manga).
final userListEntryProvider =
    Provider.family<MediaListEntry?, int>((ref, mediaId) {
  // Cherche dans la liste anime
  final animeEntry = ref.watch(userListProvider).whenOrNull(
    data: (groups) {
      for (final group in groups) {
        for (final entry in group.entries) {
          if (entry.media.id == mediaId) return entry;
        }
      }
      return null;
    },
  );
  if (animeEntry != null) return animeEntry;

  // Cherche dans la liste manga
  return ref.watch(userMangaListProvider).whenOrNull(
    data: (groups) {
      for (final group in groups) {
        for (final entry in group.entries) {
          if (entry.media.id == mediaId) return entry;
        }
      }
      return null;
    },
  );
});

/// Retourne l'entrée locale invité pour un média donné (ou null).
final guestListEntryProvider =
    Provider.family<GuestWatchlistEntry?, int>((ref, animeId) {
  final listAsync = ref.watch(guestWatchlistProvider);

  return listAsync.whenOrNull(
    data: (entries) =>
        entries.where((e) => e.animeId == animeId).firstOrNull,
  );
});
