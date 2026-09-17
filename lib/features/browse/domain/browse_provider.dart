import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/browse/domain/filter_params.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';

/// Filtres persistants — survivent à la navigation.
final browseFilterProvider =
    StateProvider<FilterParams>((ref) => const FilterParams());

/// Page unique (utilisé en interne par le screen pour charger plus).
final filteredBrowseProvider =
    FutureProvider.family<PaginatedResult, ({FilterParams params, int page})>(
        (ref, args) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.browseFiltered(params: args.params, page: args.page);
});
