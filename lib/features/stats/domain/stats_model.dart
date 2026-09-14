import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/stats/domain/user_title.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Stats cumulées calculées à partir des listes AniList de l'utilisateur.
class StatsModel {
  final int animeWatched;        // Total anime avec progress > 0 (current + completed)
  final int animeCompleted;      // Anime avec status = completed
  final int episodesWatched;     // Somme de progress pour les anime
  final int watchTimeMinutes;    // Temps de visionnage estimé en minutes

  final int mangaRead;           // Total manga avec progress > 0
  final int mangaCompleted;      // Manga avec status = completed
  final int chaptersRead;        // Somme de progress pour les manga
  final int readTimeMinutes;     // Temps de lecture estimé (chapitres × 5 min)

  final double? meanScore;       // Moyenne des scores utilisateur (non-zéro)
  final List<GenreStat> topGenres; // Top genres toutes catégories confondues

  final MediaListEntry? bestAnime;  // Anime avec le score utilisateur le plus haut
  final MediaListEntry? bestManga;  // Manga avec le score utilisateur le plus haut

  const StatsModel({
    required this.animeWatched,
    required this.animeCompleted,
    required this.episodesWatched,
    required this.watchTimeMinutes,
    required this.mangaRead,
    required this.mangaCompleted,
    required this.chaptersRead,
    required this.readTimeMinutes,
    required this.topGenres,
    this.meanScore,
    this.bestAnime,
    this.bestManga,
  });

  /// Temps de visionnage formaté lisible (ex: "4j 12h" ou "3h 20min").
  String get watchTimeFormatted => formatDuration(watchTimeMinutes);

  /// Temps de lecture estimé, même format.
  String get readTimeFormatted => formatDuration(readTimeMinutes);

  static String formatDuration(int totalMinutes) {
    final days = totalMinutes ~/ (60 * 24);
    final hours = (totalMinutes % (60 * 24)) ~/ 60;
    final minutes = totalMinutes % 60;

    if (days > 0) return '${days}j ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes}min';
  }

  /// Estimation du temps de lecture d'un chapitre de manga.
  static const minutesPerChapter = 5;

  /// Titre de profil calculé sur le cumul total.
  UserTitle get title => UserTitle.from(
        animeCompleted: animeCompleted,
        mangaCompleted: mangaCompleted,
        watchMinutes: watchTimeMinutes,
        readMinutes: readTimeMinutes,
      );

  /// Calcule les stats depuis les deux listes (anime + manga).
  static StatsModel compute({
    required List<MediaListGroup> animeGroups,
    required List<MediaListGroup> mangaGroups,
  }) {
    final allEntries = [
      ...animeGroups.expand((g) => g.entries),
      ...mangaGroups.expand((g) => g.entries),
    ];

    final animeEntries = allEntries.where((e) => !e.isManga).toList();
    final mangaEntries = allEntries.where((e) => e.isManga).toList();

    // ── Anime ─────────────────────────────────────────────────────────────────
    final animeWithProgress = animeEntries.where((e) => (e.progress ?? 0) > 0);
    final animeCompleted = animeEntries
        .where((e) => e.status == ListStatus.completed)
        .length;
    final episodesWatched = animeWithProgress
        .fold<int>(0, (sum, e) => sum + (e.progress ?? 0));
    final watchTimeMinutes = animeWithProgress.fold<int>(0, (sum, e) {
      final dur = e.media.duration ?? 24;
      return sum + (e.progress ?? 0) * dur;
    });

    // ── Manga ─────────────────────────────────────────────────────────────────
    final mangaWithProgress = mangaEntries.where((e) => (e.progress ?? 0) > 0);
    final mangaCompleted = mangaEntries
        .where((e) => e.status == ListStatus.completed)
        .length;
    final chaptersRead = mangaWithProgress
        .fold<int>(0, (sum, e) => sum + (e.progress ?? 0));

    // ── Score moyen ───────────────────────────────────────────────────────────
    final scored = allEntries
        .where((e) => (e.score ?? 0) > 0)
        .map((e) => e.score!)
        .toList();
    final meanScore = scored.isEmpty
        ? null
        : scored.reduce((a, b) => a + b) / scored.length;

    // ── Genres (fréquence pondérée par score si dispo) ────────────────────────
    final topGenres = topGenresOf(
      allEntries
          .where((e) => e.status != ListStatus.dropped)
          .map((e) => (genres: e.media.genres, score: e.score)),
    );

    // ── Best rated ────────────────────────────────────────────────────────────
    MediaListEntry? bestAnime;
    for (final e in animeEntries) {
      if ((e.score ?? 0) > 0) {
        if (bestAnime == null || (e.score! > (bestAnime.score ?? 0))) {
          bestAnime = e;
        }
      }
    }
    MediaListEntry? bestManga;
    for (final e in mangaEntries) {
      if ((e.score ?? 0) > 0) {
        if (bestManga == null || (e.score! > (bestManga.score ?? 0))) {
          bestManga = e;
        }
      }
    }

    return StatsModel(
      animeWatched: animeWithProgress.length,
      animeCompleted: animeCompleted,
      episodesWatched: episodesWatched,
      watchTimeMinutes: watchTimeMinutes,
      mangaRead: mangaWithProgress.length,
      mangaCompleted: mangaCompleted,
      chaptersRead: chaptersRead,
      readTimeMinutes: chaptersRead * minutesPerChapter,
      meanScore: meanScore,
      topGenres: topGenres,
      bestAnime: bestAnime,
      bestManga: bestManga,
    );
  }

  /// Stats depuis la watchlist NextArc (invité ou compte NextArc).
  /// Temps de visionnage et genres viennent des champs `duration` / `genres`
  /// de chaque entrée (24 min par épisode si la durée est inconnue, comme pour
  /// AniList). Pas de bestAnime/bestManga (modèle AniList).
  static StatsModel computeFromGuestList(List<GuestWatchlistEntry> entries) {
    final animeEntries = entries.where((e) => !e.isManga).toList();
    final mangaEntries = entries.where((e) => e.isManga).toList();

    final animeWithProgress = animeEntries.where((e) => (e.progress ?? 0) > 0);
    final mangaWithProgress = mangaEntries.where((e) => (e.progress ?? 0) > 0);

    final scores = entries
        .where((e) => (e.score ?? 0) > 0)
        .map((e) => e.score!)
        .toList();

    return StatsModel(
      animeWatched: animeWithProgress.length,
      animeCompleted:
          animeEntries.where((e) => e.status == ListStatus.completed).length,
      episodesWatched:
          animeWithProgress.fold(0, (s, e) => s + (e.progress ?? 0)),
      watchTimeMinutes: animeWithProgress.fold(
          0, (s, e) => s + (e.progress ?? 0) * (e.duration ?? 24)),
      mangaRead: mangaWithProgress.length,
      mangaCompleted:
          mangaEntries.where((e) => e.status == ListStatus.completed).length,
      chaptersRead:
          mangaWithProgress.fold(0, (s, e) => s + (e.progress ?? 0)),
      readTimeMinutes: mangaWithProgress.fold(
              0, (s, e) => s + (e.progress ?? 0)) *
          minutesPerChapter,
      topGenres: topGenresOf(
        entries
            .where((e) => e.status != ListStatus.dropped)
            .map((e) => (genres: e.genres, score: e.score)),
      ),
      meanScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      bestAnime: null,
      bestManga: null,
    );
  }

  /// Top 5 genres, fréquence pondérée par la note quand elle existe.
  static List<GenreStat> topGenresOf(
    Iterable<({List<String>? genres, double? score})> items,
  ) {
    final genreCount = <String, double>{};
    for (final item in items) {
      final genres = item.genres;
      if (genres == null) continue;
      final weight = (item.score ?? 0) > 0 ? item.score! / 10.0 : 1.0;
      for (final genre in genres) {
        genreCount[genre] = (genreCount[genre] ?? 0) + weight;
      }
    }
    final sorted = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isEmpty ? 1.0 : sorted.first.value;
    return sorted
        .take(5)
        .map((e) => GenreStat(name: e.key, ratio: e.value / maxCount))
        .toList();
  }
}

class GenreStat {
  final String name;
  final double ratio; // 0.0 → 1.0, relatif au genre le plus fréquent

  const GenreStat({required this.name, required this.ratio});
}
