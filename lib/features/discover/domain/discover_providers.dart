import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/onboarding/domain/onboarding_prefs.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
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
/// dans sa liste (compte NextArc, AniList seul ou invité), sinon 'ANIME'.
final contentPreferenceProvider = Provider<String>((ref) {
  final user = ref.watch(authProvider).valueOrNull?.user;
  var animeCount = 0;
  var mangaCount = 0;

  if (user?.hasFirebase == true) {
    // Compte NextArc (avec ou sans AniList lié) : liste Firestore
    final entries = ref.watch(firestoreWatchlistProvider).valueOrNull ?? [];
    animeCount = entries.where((e) => !e.isManga).length;
    mangaCount = entries.where((e) => e.isManga).length;
  } else if (user?.usesAnilistList == true) {
    // Session AniList seule
    int count(AsyncValue<List<MediaListGroup>> groups) =>
        groups.valueOrNull?.fold<int>(0, (n, g) => n + g.entries.length) ?? 0;
    animeCount = count(ref.watch(userListProvider));
    mangaCount = count(ref.watch(userMangaListProvider));
  } else {
    // Invité : liste locale
    final entries = ref.watch(guestWatchlistProvider).valueOrNull ?? [];
    animeCount = entries.where((e) => !e.isManga).length;
    mangaCount = entries.where((e) => e.isManga).length;
  }

  // À égalité (liste vide notamment) : réponse donnée à l'onboarding
  return resolveContentPreference(
    animeCount: animeCount,
    mangaCount: mangaCount,
    choice: ref.watch(contentChoiceProvider),
  );
});
