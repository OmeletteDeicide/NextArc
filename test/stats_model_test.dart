import 'package:flutter_test/flutter_test.dart';
import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

void main() {
  test('temps de visionnage et genres pour une liste NextArc', () {
    final stats = StatsModel.computeFromGuestList(const [
      GuestWatchlistEntry(
        animeId: 1,
        title: 'Avec durée',
        status: ListStatus.completed,
        progress: 10,
        score: 9,
        duration: 25,
        genres: ['Action', 'Sci-Fi'],
      ),
      GuestWatchlistEntry(
        animeId: 2,
        title: 'Durée inconnue',
        status: ListStatus.current,
        progress: 2,
        genres: ['Action'],
      ),
      GuestWatchlistEntry(
        animeId: 3,
        title: 'Manga',
        status: ListStatus.current,
        progress: 40,
        mediaType: 'MANGA',
      ),
    ]);

    // 10 × 25 min + 2 × 24 min (valeur par défaut)
    expect(stats.watchTimeMinutes, 298);
    expect(stats.episodesWatched, 12);
    expect(stats.chaptersRead, 40);
    expect(stats.topGenres.first.name, 'Action');
    expect(stats.topGenres.map((g) => g.name), contains('Sci-Fi'));
  });
}
