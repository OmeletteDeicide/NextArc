import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/activity/data/activity_repository.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/data/firestore_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/data/guest_watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_merge.dart';

final watchlistSyncServiceProvider = Provider(
  (_) => WatchlistSyncService(
    firestore: FirestoreWatchlistRepository(),
    guest: GuestWatchlistRepository(),
    activity: ActivityRepository(),
  ),
);

/// Fusionne la liste invité et la liste AniList dans la watchlist Firestore,
/// qui est la référence pour un compte NextArc. Rien n'est jamais supprimé
/// (voir [computeMergeWrites]) et rien n'est écrit sur AniList.
class WatchlistSyncService {
  WatchlistSyncService({
    required this.firestore,
    required this.guest,
    required this.activity,
  });

  final FirestoreWatchlistRepository firestore;
  final GuestWatchlistRepository guest;
  final ActivityRepository activity;

  static const _storage = FlutterSecureStorage();

  /// Marge pour absorber un décalage d'horloge entre le téléphone et AniList.
  static const _clockSkew = Duration(minutes: 10);

  static String _lastSyncKey(String uid) => 'anilist_last_sync_$uid';
  static String _favouriteMigrationKey(String uid) =>
      'favourite_migration_v1_$uid';

  /// Migration unique par compte : avant, une note ≥ 8 suffisait pour être
  /// en favori. Les entrées concernées reçoivent un ❤️ explicite.
  Future<void> migrateFavouritesFromScores(String uid) async {
    final key = _favouriteMigrationKey(uid);
    if (await _storage.read(key: key) != null) return;

    final current = await firestore.getEntries(uid);
    final writes = current.values
        .where((e) =>
            !e.deleted &&
            !e.favourite &&
            (e.score ?? 0) >= GuestWatchlistEntry.autoFavouriteScore)
        .map((e) => e.copyWith(favourite: true))
        .toList();
    await firestore.upsertMany(uid, writes);
    await _storage.write(key: key, value: 'done');
  }

  /// Verse la liste invité dans Firestore puis la vide.
  /// Retourne false s'il n'y avait rien à migrer.
  Future<bool> mergeGuestIntoFirestore(String uid) async {
    final guestEntries = await guest.getEntries();
    if (guestEntries.isEmpty) return false;

    final current = await firestore.getEntries(uid);
    await firestore.upsertMany(uid, computeMergeWrites(current, guestEntries));
    // Vidée seulement après écriture réussie : en cas d'échec on réessaiera
    await guest.clearAll();
    return true;
  }

  /// Importe les entrées AniList modifiées depuis la dernière synchro.
  /// Retourne le nombre d'entrées écrites dans Firestore.
  Future<int> mergeAnilistIntoFirestore(String uid, int anilistUserId) async {
    final startedAt = DateTime.now();
    final lastSyncMs =
        int.tryParse(await _storage.read(key: _lastSyncKey(uid)) ?? '');
    final lastSync = lastSyncMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

    final favouriteIds = await _fetchFavouriteIds(anilistUserId);
    final anilistEntries = [
      ...await _fetchList(anilistUserId, 'ANIME', favouriteIds),
      ...await _fetchList(anilistUserId, 'MANGA', favouriteIds),
    ];

    final changed = lastSync == null
        ? anilistEntries
        : anilistEntries
            .where((e) => e.updatedAt?.isAfter(lastSync) ?? false)
            .toList();

    var written = 0;
    if (changed.isNotEmpty) {
      final current = await firestore.getEntries(uid);
      final writes = computeMergeWrites(current, changed);
      await firestore.upsertMany(uid, writes);
      written = writes.length;

      // Les changements AniList comptent dans le récap du mois, sauf la
      // toute première synchro (import de toute la bibliothèque).
      if (lastSync != null && writes.isNotEmpty) {
        try {
          final inLibraryPhase = await activity.isInLibraryPhase(uid);
          await activity.recordItems(
            uid: uid,
            month: monthKey(startedAt),
            items: [
              for (final entry in writes)
                ?computeActivity(
                  before: current[entry.animeId],
                  after: entry,
                  inLibraryPhase: inLibraryPhase,
                ),
            ],
          );
        } catch (_) {
          // Le récap ne doit pas faire échouer la synchro
        }
      }
    }

    await _storage.write(
      key: _lastSyncKey(uid),
      value: startedAt.subtract(_clockSkew).millisecondsSinceEpoch.toString(),
    );
    return written;
  }

  // ── AniList ───────────────────────────────────────────────────────────────

  static const _listQuery = r'''
    query SyncList($userId: Int, $type: MediaType) {
      MediaListCollection(userId: $userId, type: $type) {
        lists {
          isCustomList
          entries {
            status
            score(format: POINT_10_DECIMAL)
            progress
            updatedAt
            media {
              id
              type
              title { romaji english }
              coverImage { large medium }
              episodes
              chapters
              duration
              genres
            }
          }
        }
      }
    }
  ''';

  static const _favouritesQuery = r'''
    query SyncFavourites($userId: Int) {
      User(id: $userId) {
        favourites {
          anime(perPage: 50) { nodes { id } }
          manga(perPage: 50) { nodes { id } }
        }
      }
    }
  ''';

  Future<Map<String, dynamic>> _query(
    String document,
    Map<String, dynamic> variables,
  ) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(document),
        variables: variables,
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException || result.data == null) {
      throw Exception('Synchro AniList impossible : ${result.exception}');
    }
    return result.data!;
  }

  Future<Set<int>> _fetchFavouriteIds(int userId) async {
    final data = await _query(_favouritesQuery, {'userId': userId});
    final favourites = data['User']?['favourites'] as Map<String, dynamic>?;
    return {
      for (final type in ['anime', 'manga'])
        for (final node in (favourites?[type]?['nodes'] as List?) ?? const [])
          if (node is Map && node['id'] is int) node['id'] as int,
    };
  }

  Future<List<GuestWatchlistEntry>> _fetchList(
    int userId,
    String type,
    Set<int> favouriteIds,
  ) async {
    final data =
        await _query(_listQuery, {'userId': userId, 'type': type});
    final lists =
        (data['MediaListCollection']?['lists'] as List?) ?? const [];

    final entries = <int, GuestWatchlistEntry>{};
    for (final list in lists.whereType<Map<String, dynamic>>()) {
      // Les listes perso dupliquent des entrées déjà présentes ailleurs
      if (list['isCustomList'] == true) continue;
      for (final raw in (list['entries'] as List?) ?? const []) {
        final entry = _toEntry(raw, favouriteIds);
        if (entry != null) entries[entry.animeId] = entry;
      }
    }
    return entries.values.toList();
  }

  GuestWatchlistEntry? _toEntry(Object? raw, Set<int> favouriteIds) {
    if (raw is! Map<String, dynamic>) return null;
    final mediaJson = raw['media'];
    if (mediaJson is! Map<String, dynamic>) return null;

    final media = MediaModel.fromJson(mediaJson);
    final status = raw['status'] == 'REPEATING' ? 'CURRENT' : raw['status'];
    final progress = raw['progress'];
    final updatedAt = raw['updatedAt'];

    return GuestWatchlistEntry.tryParse({
      'animeId': media.id,
      'title': media.displayTitle,
      'coverImage': media.coverImage,
      'status': status,
      'score': raw['score'],
      'progress': progress is int
          ? math.min(progress, GuestWatchlistEntry.maxCount)
          : null,
      'episodes': media.isManga ? media.chapters : media.episodes,
      'mediaType': media.isManga ? 'MANGA' : 'ANIME',
      'genres': media.genres,
      'duration': media.duration,
      'favourite': favouriteIds.contains(media.id),
      // AniList renvoie des secondes
      if (updatedAt is int && updatedAt > 0) 'updatedAt': updatedAt * 1000,
    });
  }
}
