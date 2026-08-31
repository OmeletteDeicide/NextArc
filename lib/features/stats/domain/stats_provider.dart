import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Calcule les stats depuis les listes anime + manga de l'utilisateur.
final statsProvider = FutureProvider<StatsModel>((ref) async {
  final animeGroups = await ref.watch(userListProvider.future);
  final mangaGroups = await ref.watch(userMangaListProvider.future);

  return StatsModel.compute(
    animeGroups: animeGroups,
    mangaGroups: mangaGroups,
  );
});
