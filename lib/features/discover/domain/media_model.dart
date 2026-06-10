/// Modèle représentant un anime retourné par l'API AniList.
class MediaModel {
  const MediaModel({
    required this.id,
    required this.titleRomaji,
    this.titleEnglish,
    this.coverImageLarge,
    this.coverImageMedium,
    this.description,
    this.averageScore,
    this.genres,
    this.episodes,
    this.status,
    this.seasonYear,
    this.season,
    this.startDate,
  });

  final int id;

  /// Titre en romaji (toujours présent).
  final String titleRomaji;

  /// Titre anglais (peut être null si non traduit).
  final String? titleEnglish;

  /// URL de la jaquette en grande résolution.
  final String? coverImageLarge;

  /// URL de la jaquette en résolution moyenne (fallback).
  final String? coverImageMedium;

  /// Synopsis — AniList renvoie du HTML, à nettoyer avant affichage.
  final String? description;

  /// Score moyen sur 100.
  final int? averageScore;

  final List<String>? genres;

  /// Nombre total d'épisodes (null si en cours / inconnu).
  final int? episodes;

  /// Statut de diffusion : FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS.
  final String? status;

  final int? seasonYear;

  /// Saison : WINTER, SPRING, SUMMER, FALL.
  final String? season;

  /// Date de début de diffusion (peut être partielle — seul year+month+day sont utilisés).
  final DateTime? startDate;

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Titre affiché : anglais si dispo, sinon romaji.
  String get displayTitle => titleEnglish ?? titleRomaji;

  /// Meilleure URL de jaquette disponible.
  String? get coverImage => coverImageLarge ?? coverImageMedium;

  /// Score formaté sur 10 (ex: "8.5") ou null.
  String? get formattedScore {
    if (averageScore == null) return null;
    return (averageScore! / 10).toStringAsFixed(1);
  }

  // ── Désérialisation depuis la réponse GraphQL ─────────────────────────────

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as Map<String, dynamic>?;

    return MediaModel(
      id: json['id'] as int,
      titleRomaji: title?['romaji'] as String? ?? '',
      titleEnglish: title?['english'] as String?,
      coverImageLarge: coverImage?['large'] as String?,
      coverImageMedium: coverImage?['medium'] as String?,
      description: json['description'] as String?,
      averageScore: json['averageScore'] as int?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      episodes: json['episodes'] as int?,
      status: json['status'] as String?,
      seasonYear: json['seasonYear'] as int?,
      season: json['season'] as String?,
      startDate: _parseDate(json['startDate'] as Map<String, dynamic>?),
    );
  }

  static DateTime? _parseDate(Map<String, dynamic>? d) {
    if (d == null) return null;
    final y = d['year'] as int?;
    final m = d['month'] as int?;
    final day = d['day'] as int?;
    if (y == null || m == null || day == null) return null;
    return DateTime(y, m, day);
  }

  @override
  String toString() => 'MediaModel(id: $id, title: $displayTitle)';
}
