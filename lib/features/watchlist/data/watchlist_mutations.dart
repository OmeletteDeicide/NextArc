/// Mutations GraphQL AniList pour modifier la liste de l'utilisateur.
class WatchlistMutations {
  /// Ajoute ou met à jour une entrée dans la liste.
  static const String saveEntry = r'''
    mutation SaveMediaListEntry(
      $mediaId: Int
      $status: MediaListStatus
      $score: Float
      $progress: Int
    ) {
      SaveMediaListEntry(
        mediaId: $mediaId
        status: $status
        score: $score
        progress: $progress
      ) {
        id
        status
        score
        progress
      }
    }
  ''';

  /// Supprime une entrée de la liste (par son id d'entrée, pas l'id de l'anime).
  static const String deleteEntry = r'''
    mutation DeleteMediaListEntry($id: Int) {
      DeleteMediaListEntry(id: $id) {
        deleted
      }
    }
  ''';
}
