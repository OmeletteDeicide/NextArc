import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Entrée de watchlist NextArc — modèle partagé entre la liste locale (invité)
/// et Firestore (compte NextArc).
class GuestWatchlistEntry {
  const GuestWatchlistEntry({
    required this.animeId,
    required this.title,
    this.coverImage,
    required this.status,
    this.score,
    this.progress,
    this.episodes,
    this.mediaType = 'ANIME',
    this.favourite = false,
    this.deleted = false,
    this.updatedAt,
  });

  static const maxTitleLength = 500;
  static const maxCount = 50000;
  static const maxUrlLength = 2048;

  final int animeId;
  final String title;
  final String? coverImage;
  final ListStatus status;
  final double? score;
  final int? progress;
  final int? episodes;
  final String mediaType;

  /// ❤️ explicite posé par l'utilisateur (ou favori importé d'AniList).
  final bool favourite;

  /// Retiré de la liste par l'utilisateur (suppression douce, Firestore) :
  /// l'entrée est masquée mais conservée pour que la fusion AniList ne la
  /// fasse pas revenir. `updatedAt` vaut alors la date de suppression.
  final bool deleted;

  /// Dernière modification : heure serveur pour Firestore, heure locale pour
  /// l'invité. Sert à départager deux versions lors d'une fusion.
  final DateTime? updatedAt;

  bool get isManga => mediaType == 'MANGA';

  /// Apparaît dans l'onglet Favoris : ❤️ ou note ≥ 8.
  bool get isFavourite => favourite || (score ?? 0) >= 8;

  String? get formattedScore {
    if (score == null || score == 0) return null;
    return score!.toStringAsFixed(score! % 1 == 0 ? 0 : 1);
  }

  String get progressLabel {
    final seen = progress ?? 0;
    if (isManga) return '$seen ch. / ${episodes ?? '?'}';
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
        'mediaType': mediaType,
        'favourite': favourite,
        if (deleted) 'deleted': true,
        if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
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
      mediaType: json['mediaType'] as String? ?? 'ANIME',
      favourite: json['favourite'] == true,
      deleted: json['deleted'] == true,
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  /// Parse une entrée venant d'une source non fiable (fichier importé, stockage
  /// local, API). Retourne null si l'entrée est invalide ; les valeurs hors
  /// limites sont ignorées plutôt que de faire échouer tout l'import.
  static GuestWatchlistEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;

    final id = raw['animeId'];
    final title = raw['title'];
    final statusRaw = raw['status'];
    final type = raw['mediaType'] ?? 'ANIME';

    if (id is! int || id <= 0) return null;
    if (title is! String || title.trim().isEmpty) return null;
    final status =
        statusRaw is String ? ListStatus.fromString(statusRaw) : null;
    if (status == null) return null;
    if (type != 'ANIME' && type != 'MANGA') return null;

    final trimmed = title.trim();
    final score = raw['score'];
    final cover = raw['coverImage'];

    return GuestWatchlistEntry(
      animeId: id,
      title: trimmed.substring(0, math.min(trimmed.length, maxTitleLength)),
      coverImage: cover is String &&
              cover.startsWith('https://') &&
              cover.length <= maxUrlLength
          ? cover
          : null,
      status: status,
      score: score is num && score > 0 && score <= 10 ? score.toDouble() : null,
      progress: _validCount(raw['progress']),
      episodes: _validCount(raw['episodes']),
      mediaType: type as String,
      favourite: raw['favourite'] == true,
      deleted: raw['deleted'] == true,
      updatedAt: _parseDate(raw['updatedAt']),
    );
  }

  static int? _validCount(Object? v) =>
      v is int && v >= 0 && v <= maxCount ? v : null;

  static DateTime? _parseDate(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        String s => DateTime.tryParse(s),
        _ => null,
      };

  GuestWatchlistEntry copyWith({
    ListStatus? status,
    double? score,
    int? progress,
    bool? favourite,
    bool? deleted,
    DateTime? updatedAt,
  }) =>
      GuestWatchlistEntry(
        animeId: animeId,
        title: title,
        coverImage: coverImage,
        status: status ?? this.status,
        score: score ?? this.score,
        progress: progress ?? this.progress,
        episodes: episodes,
        mediaType: mediaType,
        favourite: favourite ?? this.favourite,
        deleted: deleted ?? this.deleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
