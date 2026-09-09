import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Calcule les stats selon le type d'utilisateur :
/// - AniList → données complètes via l'API
/// - Firebase-only → données simplifiées depuis Firestore
/// - Invité → données simplifiées depuis Hive
final statsProvider = FutureProvider<StatsModel>((ref) async {
  final authState =
      ref.watch(authProvider).whenOrNull(data: (a) => a);
  final user = authState?.user;

  if (user?.hasAnilist == true) {
    final animeGroups = await ref.watch(userListProvider.future);
    final mangaGroups = await ref.watch(userMangaListProvider.future);
    return StatsModel.compute(
      animeGroups: animeGroups,
      mangaGroups: mangaGroups,
    );
  }

  if (user?.hasFirebase == true) {
    final entries = await ref.watch(firestoreWatchlistProvider.future);
    return StatsModel.computeFromGuestList(entries);
  }

  final entries = await ref.watch(guestWatchlistProvider.future);
  return StatsModel.computeFromGuestList(entries);
});
