import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Calcule les stats selon le type d'utilisateur :
/// - AniList sans compte NextArc → données complètes via l'API
/// - Compte NextArc → données simplifiées depuis Firestore
/// - Invité → données simplifiées depuis la liste locale
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

  if (user?.hasFirebase == true) {
    final entries = await ref.watch(firestoreWatchlistProvider.future);
    return StatsModel.computeFromGuestList(entries);
  }

  final entries = await ref.watch(guestWatchlistProvider.future);
  return StatsModel.computeFromGuestList(entries);
});
