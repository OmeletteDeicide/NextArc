/// Requêtes GraphQL pour la liste personnelle de l'utilisateur AniList.
class WatchlistQueries {
  WatchlistQueries._();

  /// Récupère toute la liste anime de l'utilisateur (groupée par statut).
  static const String mediaListCollection = '''
    query MediaListCollection(\$userId: Int) {
      MediaListCollection(userId: \$userId, type: ANIME) {
        lists {
          name
          status
          entries {
            id
            status
            score
            progress
            media {
              id
              title { romaji english }
              coverImage { large medium }
              episodes
              averageScore
              genres
              status
              startDate { year month day }
            }
          }
        }
      }
    }
  ''';

  /// Récupère les favoris anime de l'utilisateur.
  static const String userFavourites = '''
    query UserFavourites(\$userId: Int) {
      User(id: \$userId) {
        favourites {
          anime {
            nodes {
              id
              title { romaji english }
              coverImage { large medium }
              averageScore
              genres
              episodes
              status
            }
          }
        }
      }
    }
  ''';
}
