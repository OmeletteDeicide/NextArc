import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';

/// Provider de la query de recherche (texte saisi par l'utilisateur).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider des résultats de recherche, branché sur searchQueryProvider.
final searchResultsProvider = FutureProvider<PaginatedResult?>((ref) async {
  final query = ref.watch(searchQueryProvider);

  // Ne lance pas de requête si la recherche est vide
  if (query.trim().isEmpty) return null;

  final repo = ref.watch(animeRepositoryProvider);
  return repo.searchAnime(query: query, perPage: 20);
});
