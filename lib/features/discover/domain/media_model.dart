/// Modèle représentant un média (anime ou manga) retourné par l'API AniList.
class MediaModel {
  const MediaModel({
    required this.id,
    required this.titleRomaji,
    this.titleEnglish,
    this.coverImageLarge,
    this.coverImageMedium,
    this.bannerImage,
    this.description,
    this.averageScore,
    this.genres,
    this.episodes,
    this.duration,
    this.chapters,
    this.volumes,
    this.countryOfOrigin,
    this.mediaType,
    this.status,
    this.seasonYear,
    this.season,
    this.startDate,
    this.nextAiringEpisode,
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

  /// Visuel large 16:9 (bannière AniList), absent pour certains médias.
  final String? bannerImage;

  /// Synopsis — AniList renvoie du HTML, à nettoyer avant affichage.
  final String? description;

  /// Score moyen sur 100.
  final int? averageScore;

  final List<String>? genres;

  /// Nombre total d'épisodes (anime uniquement).
  final int? episodes;

  /// Durée moyenne d'un épisode en minutes (anime uniquement, fourni par AniList).
  final int? duration;

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

  /// Prochain épisode à diffuser (anime RELEASING uniquement).
  final NextAiringEpisode? nextAiringEpisode;

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool get isManga => mediaType == 'MANGA';

  /// Épisodes déjà diffusés d'un anime en cours (prochain épisode − 1), null
  /// si AniList ne l'indique pas. AniList ne donne pas cette information pour
  /// les manga en cours de publication.
  int? get airedEpisodes {
    final next = nextAiringEpisode;
    if (isManga || next == null) return null;
    return next.episode > 1 ? next.episode - 1 : 0;
  }

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
      bannerImage: json['bannerImage'] as String?,
      description: json['description'] as String?,
      averageScore: json['averageScore'] as int?,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      episodes: json['episodes'] as int?,
      duration: json['duration'] as int?,
      chapters: json['chapters'] as int?,
      volumes: json['volumes'] as int?,
      countryOfOrigin: json['countryOfOrigin'] as String?,
      mediaType: json['type'] as String?,
      status: json['status'] as String?,
      seasonYear: json['seasonYear'] as int?,
      season: json['season'] as String?,
      startDate: _parseDate(json['startDate'] as Map<String, dynamic>?),
      nextAiringEpisode: NextAiringEpisode.fromJson(
          json['nextAiringEpisode'] as Map<String, dynamic>?),
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
  String toString() =>
      'MediaModel(id: $id, type: $mediaType, title: $displayTitle)';
}

class NextAiringEpisode {
  final int episode;
  final DateTime airingAt;

  const NextAiringEpisode({required this.episode, required this.airingAt});

  static NextAiringEpisode? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final ts = json['airingAt'] as int?;
    final ep = json['episode'] as int?;
    if (ts == null || ep == null) return null;
    return NextAiringEpisode(
      episode: ep,
      airingAt: DateTime.fromMillisecondsSinceEpoch(ts * 1000),
    );
  }
}
