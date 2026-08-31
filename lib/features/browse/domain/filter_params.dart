/// Paramètres de filtre pour la navigation avancée.
/// Tous les champs sont optionnels — null = pas de filtre sur ce champ.
class FilterParams {
  final String mediaType;        // 'ANIME' ou 'MANGA'
  final List<String> genres;     // ex: ['Action', 'Fantasy']
  final List<String> formats;    // ex: ['TV', 'MOVIE']
  final int? yearFrom;           // année minimum de sortie
  final int? yearTo;             // année maximum de sortie
  final int? minScore;           // score AniList minimum (0-100)
  final String? status;          // 'RELEASING', 'FINISHED', etc.
  final String sort;             // valeur AniList: 'TRENDING_DESC', etc.

  const FilterParams({
    this.mediaType = 'ANIME',
    this.genres = const [],
    this.formats = const [],
    this.yearFrom,
    this.yearTo,
    this.minScore,
    this.status,
    this.sort = 'POPULARITY_DESC',
  });

  FilterParams copyWith({
    String? mediaType,
    List<String>? genres,
    List<String>? formats,
    int? yearFrom,
    int? yearTo,
    int? minScore,
    String? status,
    String? sort,
    bool clearYearFrom = false,
    bool clearYearTo = false,
    bool clearMinScore = false,
    bool clearStatus = false,
  }) {
    return FilterParams(
      mediaType: mediaType ?? this.mediaType,
      genres: genres ?? this.genres,
      formats: formats ?? this.formats,
      yearFrom: clearYearFrom ? null : (yearFrom ?? this.yearFrom),
      yearTo: clearYearTo ? null : (yearTo ?? this.yearTo),
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      status: clearStatus ? null : (status ?? this.status),
      sort: sort ?? this.sort,
    );
  }

  bool get isEmpty =>
      genres.isEmpty &&
      formats.isEmpty &&
      yearFrom == null &&
      yearTo == null &&
      minScore == null &&
      status == null;

  int get activeCount {
    int count = 0;
    if (genres.isNotEmpty) count++;
    if (formats.isNotEmpty) count++;
    if (yearFrom != null || yearTo != null) count++;
    if (minScore != null) count++;
    if (status != null) count++;
    return count;
  }

  // ── Listes de valeurs AniList ─────────────────────────────────────────────

  static const List<String> animeGenres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy',
    'Horror', 'Mecha', 'Music', 'Mystery', 'Psychological',
    'Romance', 'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural',
    'Thriller',
  ];

  static const List<String> mangaGenres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy',
    'Horror', 'Mystery', 'Psychological', 'Romance', 'Sci-Fi',
    'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
  ];

  static const List<({String value, String label})> animeFormats = [
    (value: 'TV', label: 'TV'),
    (value: 'MOVIE', label: 'Film'),
    (value: 'OVA', label: 'OVA'),
    (value: 'ONA', label: 'ONA'),
    (value: 'SPECIAL', label: 'Spécial'),
  ];

  static const List<({String value, String label})> sortOptions = [
    (value: 'POPULARITY_DESC', label: 'Popularité'),
    (value: 'TRENDING_DESC', label: 'Tendance'),
    (value: 'SCORE_DESC', label: 'Score'),
    (value: 'START_DATE_DESC', label: 'Plus récent'),
    (value: 'FAVOURITES_DESC', label: 'Favoris'),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FilterParams) return false;
    return mediaType == other.mediaType &&
        _listEq(genres, other.genres) &&
        _listEq(formats, other.formats) &&
        yearFrom == other.yearFrom &&
        yearTo == other.yearTo &&
        minScore == other.minScore &&
        status == other.status &&
        sort == other.sort;
  }

  @override
  int get hashCode => Object.hash(
        mediaType,
        Object.hashAll(genres),
        Object.hashAll(formats),
        yearFrom,
        yearTo,
        minScore,
        status,
        sort,
      );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const List<({String value, String label})> statusOptions = [
    (value: 'RELEASING', label: 'En cours'),
    (value: 'FINISHED', label: 'Terminé'),
    (value: 'NOT_YET_RELEASED', label: 'À venir'),
    (value: 'HIATUS', label: 'En pause'),
  ];
}
