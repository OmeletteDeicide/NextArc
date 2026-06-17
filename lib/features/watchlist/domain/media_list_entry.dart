import 'package:nextarc/features/discover/domain/media_model.dart';

/// Statuts AniList traduits.
enum ListStatus {
  current('CURRENT', 'En cours'),
  completed('COMPLETED', 'Terminé'),
  planning('PLANNING', 'Prévu'),
  paused('PAUSED', 'En pause'),
  dropped('DROPPED', 'Abandonné');

  const ListStatus(this.anilistValue, this.label);
  final String anilistValue;
  final String label;

  static ListStatus? fromString(String? value) {
    for (final s in values) {
      if (s.anilistValue == value) return s;
    }
    return null;
  }
}

/// Une entrée dans la liste personnelle de l'utilisateur.
class MediaListEntry {
  const MediaListEntry({
    required this.id,
    required this.media,
    this.status,
    this.score,
    this.progress,
  });

  final int id;
  final MediaModel media;
  final ListStatus? status;

  /// Score donné par l'utilisateur (0–10, 0 = non noté).
  final double? score;

  /// Nombre d'épisodes vus.
  final int? progress;

  /// Score affiché (ex: "8.5" ou null si non noté).
  String? get formattedScore {
    if (score == null || score == 0) return null;
    return score!.toStringAsFixed(score! % 1 == 0 ? 0 : 1);
  }

  bool get isManga => media.isManga;

  /// Progression formatée (ex: "12 / 24" ou "12 ch. / 80").
  String get progressLabel {
    final seen = progress ?? 0;
    if (isManga) {
      return '$seen ch. / ${media.chapters ?? '?'}';
    }
    return '$seen / ${media.episodes ?? '?'}';
  }

  factory MediaListEntry.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as Map<String, dynamic>;
    return MediaListEntry(
      id: json['id'] as int,
      media: MediaModel.fromJson(mediaJson),
      status: ListStatus.fromString(json['status'] as String?),
      score: (json['score'] as num?)?.toDouble(),
      progress: json['progress'] as int?,
    );
  }
}

/// Un groupe de la liste (ex: "En cours", "Terminé"...).
class MediaListGroup {
  const MediaListGroup({
    required this.status,
    required this.entries,
  });

  final ListStatus status;
  final List<MediaListEntry> entries;
}
