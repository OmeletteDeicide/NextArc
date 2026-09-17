import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Ids des médias présents dans la liste de l'utilisateur courant, quelle que
/// soit la source (AniList seul, compte NextArc ou invité).
final watchlistMediaIdsProvider = Provider<Set<int>>((ref) {
  final user = ref.watch(authProvider).whenOrNull(data: (a) => a.user);

  if (user?.usesAnilistList == true) {
    Set<int> idsOf(AsyncValue groups) =>
        groups.whenOrNull(
          data: (value) => {
            for (final group in value)
              for (final entry in group.entries) entry.media.id as int,
          },
        ) ??
        const <int>{};
    return {
      ...idsOf(ref.watch(userListProvider)),
      ...idsOf(ref.watch(userMangaListProvider)),
    };
  }

  final entries = user?.hasFirebase == true
      ? ref.watch(firestoreWatchlistProvider).whenOrNull(data: (e) => e)
      : ref.watch(guestWatchlistProvider).whenOrNull(data: (e) => e);
  return {for (final entry in entries ?? const []) entry.animeId};
});

/// Le média est-il déjà dans la liste ?
final inWatchlistProvider = Provider.family<bool, int>(
  (ref, mediaId) => ref.watch(watchlistMediaIdsProvider).contains(mediaId),
);

/// Place d'un média dans la liste : statut et ❤️ (null s'il n'y est pas).
/// Compte AniList seul : pas de ❤️, une note ≥ 8 en tient lieu.
final watchlistPlacementProvider =
    Provider.family<({ListStatus status, bool favourite})?, int>((ref, id) {
  final user = ref.watch(authProvider).whenOrNull(data: (a) => a.user);

  if (user?.usesAnilistList == true) {
    for (final async in [
      ref.watch(userListProvider),
      ref.watch(userMangaListProvider),
    ]) {
      for (final group in async.valueOrNull ?? const <MediaListGroup>[]) {
        for (final entry in group.entries) {
          if (entry.media.id == id) {
            return (
              status: entry.status ?? group.status,
              favourite: (entry.score ?? 0) >=
                  GuestWatchlistEntry.autoFavouriteScore,
            );
          }
        }
      }
    }
    return null;
  }

  final entries = user?.hasFirebase == true
      ? ref.watch(firestoreWatchlistProvider).valueOrNull
      : ref.watch(guestWatchlistProvider).valueOrNull;
  for (final entry in entries ?? const <GuestWatchlistEntry>[]) {
    if (entry.animeId == id) {
      return (status: entry.status, favourite: entry.favourite);
    }
  }
  return null;
});
