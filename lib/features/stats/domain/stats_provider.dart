import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Calcule les stats selon le type d'utilisateur :
/// - AniList sans compte NextArc → données complètes via l'API
/// - Compte NextArc → watchlist Firestore
/// - Invité → liste locale
final statsProvider = FutureProvider<StatsModel>((ref) async {
  final authState =
      ref.watch(authProvider).whenOrNull(data: (a) => a);
  final user = authState?.user;

  if (user?.usesAnilistList == true) {
    final animeGroups = await ref.watch(userListProvider.future);
    final mangaGroups = await ref.watch(userMangaListProvider.future);
    return StatsModel.compute(
      animeGroups: animeGroups,
      mangaGroups: mangaGroups,
    );
  }

  final entries = user?.hasFirebase == true
      ? await ref.watch(firestoreWatchlistProvider.future)
      : await ref.watch(guestWatchlistProvider.future);
  return StatsModel.computeFromGuestList(await _withMetadata(entries));
});

const _metadataQuery = r'''
  query StatsMetadata($ids: [Int]) {
    Page(perPage: 50) {
      media(id_in: $ids) { id genres duration }
    }
  }
''';

/// Complète en mémoire genres / durée des entrées ajoutées avant que ces
/// champs soient stockés (API AniList publique, par lots de 50, mise en cache
/// par le client GraphQL). Rien n'est réécrit : cela fausserait les dates de
/// modification utilisées par la fusion. En cas d'erreur, stats sans ces infos.
Future<List<GuestWatchlistEntry>> _withMetadata(
  List<GuestWatchlistEntry> entries,
) async {
  final missingIds = entries
      .where((e) => e.genres == null || (!e.isManga && e.duration == null))
      .map((e) => e.animeId)
      .toList();
  if (missingIds.isEmpty) return entries;

  final metadata = <int, ({List<String>? genres, int? duration})>{};
  try {
    for (var i = 0; i < missingIds.length; i += 50) {
      final result = await AnilistClient.instance.query(
        QueryOptions(
          document: gql(_metadataQuery),
          variables: {'ids': missingIds.skip(i).take(50).toList()},
        ),
      );
      if (result.hasException) break;
      final media = (result.data?['Page']?['media'] as List?) ?? const [];
      for (final m in media.whereType<Map<String, dynamic>>()) {
        final id = m['id'];
        if (id is! int) continue;
        metadata[id] = (
          genres: (m['genres'] as List?)?.whereType<String>().toList(),
          duration: m['duration'] as int?,
        );
      }
    }
  } catch (_) {
    // Hors ligne / rate limit : on calcule avec ce qu'on a
  }

  return [
    for (final entry in entries)
      if (metadata[entry.animeId] case final meta?)
        entry.copyWith(
          genres: entry.genres ?? meta.genres,
          duration: entry.duration ?? meta.duration,
        )
      else
        entry,
  ];
}
