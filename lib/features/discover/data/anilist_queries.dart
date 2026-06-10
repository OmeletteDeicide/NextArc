/// Toutes les requêtes GraphQL vers l'API AniList.
/// Centralisées ici pour faciliter la maintenance.
class AnilistQueries {
  AnilistQueries._();

  /// Fragment commun — champs récupérés pour chaque anime.
  static const String _mediaFields = '''
    id
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

  // ── 3. Recherche par titre ─────────────────────────────────────────────────

  static const String searchAnime = '''
    query SearchAnime(\$search: String, \$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
        }
        media(search: \$search, type: ANIME, isAdult: false) {
          $_mediaFields
        }
      }
    }
  ''';
}
