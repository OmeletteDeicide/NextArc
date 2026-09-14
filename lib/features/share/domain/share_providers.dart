import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Une jaquette de la carte « Mes préférés ».
class FavouriteCover {
  const FavouriteCover({
    required this.coverUrl,
    required this.title,
    this.score,
  });

  final String coverUrl;
  final String title;
  final double? score;
}

/// Nombre de jaquettes affichées : des lignes complètes de 3 (9, 6 ou 3),
/// 0 s'il y a moins de 3 favoris (la carte n'est alors pas proposée).
int collageSize(int favouritesCount) => switch (favouritesCount) {
      >= 9 => 9,
      >= 6 => 6,
      >= 3 => 3,
      _ => 0,
    };

/// Médias de la carte « Mes préférés » : les ❤️, triés par note.
final shareFavouritesProvider =
    FutureProvider<List<FavouriteCover>>((ref) async {
  final user = (await ref.watch(authProvider.future)).user;

  // Compte AniList seul : favoris AniList, puis entrées notées ≥ 8
  if (user?.usesAnilistList == true) {
    final favourites = await ref.watch(userFavouritesProvider.future);
    final entries = [
      ...await ref.watch(userListProvider.future),
      ...await ref.watch(userMangaListProvider.future),
    ].expand((g) => g.entries).where((e) => (e.score ?? 0) >= 8).toList()
      ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    final seen = <int>{};
    return [
      for (final media in favourites)
        if (media.coverImage != null && seen.add(media.id))
          FavouriteCover(coverUrl: media.coverImage!, title: media.displayTitle),
      for (final entry in entries)
        if (entry.media.coverImage != null && seen.add(entry.media.id))
          FavouriteCover(
            coverUrl: entry.media.coverImage!,
            title: entry.media.displayTitle,
            score: entry.score,
          ),
    ];
  }

  final entries = user?.hasFirebase == true
      ? await ref.watch(firestoreWatchlistProvider.future)
      : await ref.watch(guestWatchlistProvider.future);
  final liked = entries
      .where((e) => e.favourite && e.coverImage != null)
      .toList()
    ..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

  return [
    for (final e in liked)
      FavouriteCover(coverUrl: e.coverImage!, title: e.title, score: e.score),
  ];
});
