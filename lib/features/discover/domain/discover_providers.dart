import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

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

/// Provider pour les manga tendance.
final trendingMangaProvider = FutureProvider<PaginatedResult>((ref) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.getTrendingManga(perPage: 20);
});

/// Provider pour les manga en cours de publication.
final releasingMangaProvider = FutureProvider<PaginatedResult>((ref) {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.getReleasingManga(perPage: 20);
});

/// Préférence contenu : 'MANGA' si l'utilisateur a plus de manga que d'anime
/// dans sa watchlist (AniList ou invité), sinon 'ANIME' (défaut).
final contentPreferenceProvider = Provider<String>((ref) {
  // Listes AniList (connecté)
  final animeCount = ref
          .watch(userListProvider)
          .whenOrNull(
            data: (groups) => groups.expand((g) => g.entries).length,
          ) ??
      0;
  final mangaCount = ref
          .watch(userMangaListProvider)
          .whenOrNull(
            data: (groups) => groups.expand((g) => g.entries).length,
          ) ??
      0;

  // Liste locale invité
  final guestEntries = ref.watch(guestWatchlistProvider).whenOrNull(
            data: (entries) => entries,
          ) ??
      [];
  final guestAnimeCount = guestEntries.where((e) => !e.isManga).length;
  final guestMangaCount = guestEntries.where((e) => e.isManga).length;

  final totalAnime = animeCount + guestAnimeCount;
  final totalManga = mangaCount + guestMangaCount;
  return totalManga > totalAnime ? 'MANGA' : 'ANIME';
});
