/// Requête GraphQL pour les recommandations d'un anime.
class RecoQueries {
  RecoQueries._();

  static const String animeRecommendations = '''
    query AnimeRecommendations(\$id: Int) {
      Media(id: \$id, type: ANIME) {
        id
        title { romaji english }
        recommendations(sort: RATING_DESC, perPage: 8) {
          nodes {
            rating
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { large medium }
              averageScore
              genres
              episodes
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
