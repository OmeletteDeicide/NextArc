/// Toutes les requêtes GraphQL vers l'API AniList.
/// Centralisées ici pour faciliter la maintenance.
class AnilistQueries {
  AnilistQueries._();

  /// Fragment commun — champs récupérés pour chaque média (anime ou manga).
  static const String _mediaFields = '''
    id
    type
    title {
      romaji
      english
    }
    coverImage {
      large
      medium
    }
    description(asHtml: false)
    averageScore
    genres
    episodes
    chapters
    volumes
    countryOfOrigin
    status
    seasonYear
    season
    startDate { year month day }
  ''';

  // ── 1. Anime tendance ──────────────────────────────────────────────────────

  static const String trendingAnime = '''
    query TrendingAnime(\$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(sort: TRENDING_DESC, type: ANIME, isAdult: false) {
          $_mediaFields
        }
      }
    }
  ''';

  // ── 2. Anime de la saison en cours ─────────────────────────────────────────

  static const String seasonalAnime = '''
    query SeasonalAnime(
      \$season: MediaSeason,
      \$seasonYear: Int,
      \$page: Int,
      \$perPage: Int
    ) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(
          season: \$season,
          seasonYear: \$seasonYear,
          type: ANIME,
          isAdult: false,
          sort: POPULARITY_DESC
        ) {
          $_mediaFields
        }
      }
    }
  ''';

  // ── 3. Manga tendance ─────────────────────────────────────────────────────

  static const String trendingManga = '''
    query TrendingManga(\$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(sort: TRENDING_DESC, type: MANGA, isAdult: false) {
          $_mediaFields
        }
      }
    }
  ''';

  // ── 4. Manga en cours de publication ──────────────────────────────────────

  static const String releasingManga = '''
    query ReleasingManga(\$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(status: RELEASING, type: MANGA, isAdult: false, sort: POPULARITY_DESC) {
          $_mediaFields
        }
      }
    }
  ''';

  // ── 5. Recherche par titre ─────────────────────────────────────────────────

  static const String searchAnime = '''
    query SearchAnime(\$search: String, \$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(search: \$search, isAdult: false) {
          $_mediaFields
        }
      }
    }
  ''';

  // ── 6. Navigation avancée avec filtres ────────────────────────────────────

  static const String browseMedia = '''
    query BrowseMedia(
      \$type: MediaType,
      \$genre_in: [String],
      \$format_in: [MediaFormat],
      \$seasonYear_greater: Int,
      \$seasonYear_lesser: Int,
      \$averageScore_greater: Int,
      \$status: MediaStatus,
      \$sort: [MediaSort],
      \$page: Int,
      \$perPage: Int
    ) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(
          type: \$type,
          genre_in: \$genre_in,
          format_in: \$format_in,
          seasonYear_greater: \$seasonYear_greater,
          seasonYear_lesser: \$seasonYear_lesser,
          averageScore_greater: \$averageScore_greater,
          status: \$status,
          sort: \$sort,
          isAdult: false
        ) {
          $_mediaFields
        }
      }
    }
  ''';
}
