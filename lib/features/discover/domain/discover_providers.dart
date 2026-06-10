import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';

/// Provider pour les anime tendance (page 1, 20 items).
final trendingAnimeProvider = FutureProvider<PaginatedResult>((ref) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.getTrending(perPage: 20);
});

/// Provider pour les anime de la saison en cours.
final seasonalAnimeProvider = FutureProvider<PaginatedResult>((ref) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.getCurrentSeason(perPage: 20);
});
