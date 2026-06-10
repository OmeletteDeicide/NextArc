/// Requête GraphQL pour la fiche détaillée d'un anime.
class DetailQueries {
  DetailQueries._();

  static const String animeDetail = '''
    query AnimeDetail(\$id: Int) {
      Media(id: \$id, type: ANIME) {
        id
        title {
          romaji
          english
          native
        }
        coverImage {
          large
          extraLarge
        }
        bannerImage
        description(asHtml: false)
        averageScore
        meanScore
        genres
        episodes
        duration
        status
        seasonYear
        season
        source
        studios(isMain: true) {
          nodes {
            name
          }
        }
        recommendations(sort: RATING_DESC, perPage: 6) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { large medium }
              averageScore
            }
          }
        }
      }
    }
  ''';
}
