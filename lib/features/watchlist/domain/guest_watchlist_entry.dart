import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Entrée de watchlist locale pour le mode invité.
class GuestWatchlistEntry {
  const GuestWatchlistEntry({
    required this.animeId,
    required this.title,
    this.coverImage,
    required this.status,
    this.score,
    this.progress,
    this.episodes,
  });

  final int animeId;
  final String title;
  final String? coverImage;
  final ListStatus status;
  final double? score;
  final int? progress;
  final int? episodes;

  String? get formattedScore {
    if (score == null || score == 0) return null;
    return score!.toStringAsFixed(score! % 1 == 0 ? 0 : 1);
  }

  String get progressLabel {
    final seen = progress ?? 0;
    return '$seen / ${episodes ?? '?'}';
  }

  Map<String, dynamic> toJson() => {
        'animeId': animeId,
        'title': title,
        if (coverImage != null) 'coverImage': coverImage,
        'status': status.anilistValue,
        if (score != null) 'score': score,
        if (progress != null) 'progress': progress,
        if (episodes != null) 'episodes': episodes,
      };

  factory GuestWatchlistEntry.fromJson(Map<String, dynamic> json) {
    return GuestWatchlistEntry(
      animeId: json['animeId'] as int,
      title: json['title'] as String,
      coverImage: json['coverImage'] as String?,
      status: ListStatus.fromString(json['status'] as String?) ??
          ListStatus.planning,
      score: (json['score'] as num?)?.toDouble(),
      progress: json['progress'] as int?,
      episodes: json['episodes'] as int?,
    );
  }

  GuestWatchlistEntry copyWith({
    ListStatus? status,
    double? score,
    int? progress,
  }) =>
      GuestWatchlistEntry(
        animeId: animeId,
        title: title,
        coverImage: coverImage,
        status: status ?? this.status,
        score: score ?? this.score,
        progress: progress ?? this.progress,
        episodes: episodes,
      );
}
