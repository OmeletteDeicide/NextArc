/// Requête GraphQL pour la fiche détaillée d'un média (anime ou manga).
class DetailQueries {
  DetailQueries._();

  static const String animeDetail = '''
    query MediaDetail(\$id: Int) {
      Media(id: \$id) {
        id
        type
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
        chapters
        volumes
        countryOfOrigin
        duration
        status
        seasonYear
        season
        source
        startDate { year month day }
        studios(isMain: true) {
          nodes {
            name
          }
        }
        recommendations(sort: RATING_DESC, perPage: 6) {
          nodes {
            mediaRecommendation {
              id
              type
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
