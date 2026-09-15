import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
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
