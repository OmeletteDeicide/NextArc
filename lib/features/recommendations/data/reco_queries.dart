/// Requête GraphQL pour les recommandations d'un anime.
class RecoQueries {
  RecoQueries._();

  static const String animeRecommendations = '''
    query AnimeRecommendations(\$id: Int) {
      Media(id: \$id) {
        id
        title { romaji english }
        recommendations(sort: RATING_DESC, perPage: 8) {
          nodes {
            rating
            mediaRecommendation {
              id
              type
              title { romaji english }
              coverImage { large medium }
              averageScore
              genres
              episodes
              chapters
              status
              seasonYear
              season
              description(asHtml: false)
            }
          }
        }
      }
    }
  ''';
}
