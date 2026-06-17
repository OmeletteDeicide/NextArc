/// Modèle représentant un média (anime ou manga) retourné par l'API AniList.
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
    this.chapters,
    this.volumes,
    this.countryOfOrigin,
    this.mediaType,
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

  /// Nombre total d'épisodes (anime uniquement).
  final int? episodes;

  /// Nombre total de chapitres (manga uniquement).
  final int? chapters;

  /// Nombre de volumes (manga uniquement).
  final int? volumes;

  /// Pays d'origine : JP = manga, KR = manhwa, CN = manhua.
  final String? countryOfOrigin;

  /// Type AniList : 'ANIME' ou 'MANGA'.
  final String? mediaType;

  /// Statut de diffusion/publication.
  final String? status;

  final int? seasonYear;

  /// Saison : WINTER, SPRING, SUMMER, FALL (anime uniquement).
  final String? season;

  /// Date de début.
  final DateTime? startDate;

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get isManga => mediaType == 'MANGA';

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
      chapters: json['chapters'] as int?,
      volumes: json['volumes'] as int?,
      countryOfOrigin: json['countryOfOrigin'] as String?,
      mediaType: json['type'] as String?,
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
  String toString() => 'MediaModel(id: $id, type: $mediaType, title: $displayTitle)';
}
