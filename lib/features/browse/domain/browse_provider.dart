import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';

/// Résultats de la navigation filtrée.
/// Paramétré par [FilterParams] pour invalider automatiquement quand les filtres changent.
final filteredBrowseProvider =
    FutureProvider.family<PaginatedResult, FilterParams>((ref, params) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.browseFiltered(params: params);
});
