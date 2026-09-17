import 'dart:math' as math;

import 'package:nextarc/features/stats/domain/stats_model.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Clé d'un mois au format `yyyy-MM` (heure locale).
String monthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// Clé du mois précédant [date].
String previousMonthKey(DateTime date) =>
    monthKey(DateTime(date.year, date.month - 1));

/// Période après le démarrage (création du compte / premier usage invité)
/// pendant laquelle un ajout directement en « Terminé » est considéré comme
/// du remplissage de bibliothèque, pas du visionnage du mois.
const libraryPhase = Duration(days: 30);

/// Activité cumulée d'un média sur un mois.
class ActivityItem {
  const ActivityItem({
    required this.mediaId,
    required this.title,
    required this.mediaType,
    this.coverImage,
    this.genres,
    this.duration,
    this.progressAdded = 0,
    this.completed = false,
    this.favourite = false,
    this.score,
  });

  final int mediaId;
  final String title;
  final String mediaType;
  final String? coverImage;
  final List<String>? genres;
  final int? duration;

  /// Épisodes (anime) ou chapitres (manga) vus pendant le mois.
  final int progressAdded;

  /// Terminé pendant le mois.
  final bool completed;

  /// État du ❤️ / de la note lors de la dernière activité du mois.
  final bool favourite;
  final double? score;

  bool get isManga => mediaType == 'MANGA';

  /// Ajoute l'activité [next] (plus récente) à celle-ci.
  ActivityItem accumulate(ActivityItem next) => ActivityItem(
        mediaId: mediaId,
        title: next.title,
        mediaType: next.mediaType,
        coverImage: next.coverImage ?? coverImage,
        genres: next.genres ?? genres,
        duration: next.duration ?? duration,
        progressAdded: progressAdded + next.progressAdded,
        completed: completed || next.completed,
        favourite: next.favourite,
        score: next.score ?? score,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'mediaType': mediaType,
        if (coverImage != null) 'coverImage': coverImage,
        if (genres != null) 'genres': genres,
        if (duration != null) 'duration': duration,
        'progressAdded': progressAdded,
        if (completed) 'completed': true,
        'favourite': favourite,
        if (score != null) 'score': score,
      };

  /// Lecture tolérante (document Firestore ou stockage local).
  static ActivityItem? tryParse(String id, Object? raw) {
    final mediaId = int.tryParse(id);
    if (mediaId == null || raw is! Map) return null;
    final title = raw['title'];
    if (title is! String) return null;
    final progress = raw['progressAdded'];
    final score = raw['score'];
    final duration = raw['duration'];
    return ActivityItem(
      mediaId: mediaId,
      title: title,
      mediaType: raw['mediaType'] == 'MANGA' ? 'MANGA' : 'ANIME',
      coverImage: raw['coverImage'] as String?,
      genres: (raw['genres'] as List?)?.whereType<String>().toList(),
      duration: duration is int ? duration : null,
      progressAdded: progress is int && progress > 0 ? progress : 0,
      completed: raw['completed'] == true,
      favourite: raw['favourite'] == true,
      score: score is num ? score.toDouble() : null,
    );
  }
}

/// Activité réelle d'une modification de la liste, ou null si elle ne compte
/// pas dans le récap du mois :
/// - épisodes/chapitres ajoutés (différence seulement) ;
/// - passage à « Terminé » ;
/// - ❤️ ajouté ou note posée/modifiée ;
/// - un nouveau média ajouté directement en « Terminé » pendant la
///   [libraryPhase] est du remplissage de bibliothèque → ignoré.
///
/// Ne concerne que le récap mensuel : les stats totales et les titres sont
/// calculés sur la liste complète.
ActivityItem? computeActivity({
  required GuestWatchlistEntry? before,
  required GuestWatchlistEntry after,
  required bool inLibraryPhase,
}) {
  if (after.deleted) return null;

  final previous = before == null || before.deleted ? null : before;
  final isNew = previous == null;
  final isCompleted = after.status == ListStatus.completed;

  if (isNew && isCompleted && inLibraryPhase) return null;

  final progressAdded =
      math.max(0, (after.progress ?? 0) - (previous?.progress ?? 0));
  final completedNow =
      isCompleted && previous?.status != ListStatus.completed;
  final likedNow = after.favourite && !(previous?.favourite ?? false);
  final scoredNow = after.score != null && after.score != previous?.score;

  if (progressAdded == 0 && !completedNow && !likedNow && !scoredNow) {
    return null;
  }

  return ActivityItem(
    mediaId: after.animeId,
    title: after.title,
    mediaType: after.mediaType,
    coverImage: after.coverImage,
    genres: after.genres,
    duration: after.duration,
    progressAdded: progressAdded,
    completed: completedNow,
    favourite: after.favourite,
    score: after.score,
  );
}

/// Récap d'un mois calculé depuis son journal d'activité.
class MonthlyRecap {
  const MonthlyRecap({
    required this.month,
    required this.episodesWatched,
    required this.watchTimeMinutes,
    required this.chaptersRead,
    required this.readTimeMinutes,
    required this.animeCompleted,
    required this.mangaCompleted,
    required this.topGenres,
    required this.highlights,
  });

  /// Mois `yyyy-MM`.
  final String month;
  final int episodesWatched;
  final int watchTimeMinutes;
  final int chaptersRead;
  final int readTimeMinutes;
  final int animeCompleted;
  final int mangaCompleted;
  final List<GenreStat> topGenres;

  /// Médias du mois : notes ≥ 8 d'abord, puis les ❤️, puis le reste.
  final List<ActivityItem> highlights;

  bool get isEmpty => highlights.isEmpty;
  int get completed => animeCompleted + mangaCompleted;

  DateTime get date {
    final parts = month.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  String get watchTimeFormatted => StatsModel.formatDuration(watchTimeMinutes);
  String get readTimeFormatted => StatsModel.formatDuration(readTimeMinutes);

  factory MonthlyRecap.fromItems(String month, Iterable<ActivityItem> items) {
    final all = items.toList();
    final anime = all.where((i) => !i.isManga);
    final manga = all.where((i) => i.isManga);

    int group(ActivityItem i) {
      if ((i.score ?? 0) >= GuestWatchlistEntry.autoFavouriteScore) return 0;
      if (i.favourite) return 1;
      return 2;
    }

    final highlights = [...all]..sort((a, b) {
        final byGroup = group(a).compareTo(group(b));
        if (byGroup != 0) return byGroup;
        final byScore = (b.score ?? 0).compareTo(a.score ?? 0);
        if (byScore != 0) return byScore;
        return b.progressAdded.compareTo(a.progressAdded);
      });

    return MonthlyRecap(
      month: month,
      episodesWatched: anime.fold(0, (s, i) => s + i.progressAdded),
      watchTimeMinutes:
          anime.fold(0, (s, i) => s + i.progressAdded * (i.duration ?? 24)),
      chaptersRead: manga.fold(0, (s, i) => s + i.progressAdded),
      readTimeMinutes: manga.fold(
          0, (s, i) => s + i.progressAdded * StatsModel.minutesPerChapter),
      animeCompleted: anime.where((i) => i.completed).length,
      mangaCompleted: manga.where((i) => i.completed).length,
      topGenres: StatsModel.topGenresOf(
        all.map((i) => (genres: i.genres, score: i.score)),
      ),
      highlights: highlights,
    );
  }
}
