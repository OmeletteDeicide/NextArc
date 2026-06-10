import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/data/watchlist_repository.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

final watchlistRepositoryProvider = Provider((_) => WatchlistRepository());

/// Liste anime groupée par statut — nécessite d'être connecté.
final userListProvider = FutureProvider<List<MediaListGroup>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  if (!auth.isAuthenticated || auth.user == null) return [];

  final repo = ref.read(watchlistRepositoryProvider);
  return repo.getUserList(auth.user!.id);
});

/// Favoris anime de l'utilisateur.
final userFavouritesProvider = FutureProvider<List<MediaModel>>((ref) async {
  final auth = await ref.watch(authProvider.future);
  if (!auth.isAuthenticated || auth.user == null) return [];

  final repo = ref.read(watchlistRepositoryProvider);
  return repo.getUserFavourites(auth.user!.id);
});
