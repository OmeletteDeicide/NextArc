import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/watchlist/data/watchlist_mutations.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Repository pour les mutations de liste (écriture vers AniList).
class MutationRepository {
  final GraphQLClient _client;

  MutationRepository({GraphQLClient? client})
      : _client = client ?? AnilistClient.instance;

  /// Sauvegarde (crée ou met à jour) une entrée dans la liste.
  ///
  /// Retourne l'entrée mise à jour si succès, lance une exception sinon.
  Future<Map<String, dynamic>> saveEntry({
    required int mediaId,
    required ListStatus status,
    double? score,
    int? progress,
  }) async {
    // On n'inclut PAS les clés nulles — AniList rejette les variables null explicites
    final variables = <String, dynamic>{
      'mediaId': mediaId,
      'status': status.anilistValue,
    };
    if (score != null && score > 0) variables['score'] = score;
    if (progress != null && progress > 0) variables['progress'] = progress;

    final result = await _client.mutate(
      MutationOptions(
        document: gql(WatchlistMutations.saveEntry),
        variables: variables,
      ),
    );

    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.firstOrNull?.message
          ?? result.exception?.linkException?.toString()
          ?? 'Erreur inconnue';
      throw Exception(msg);
    }

    return result.data!['SaveMediaListEntry'] as Map<String, dynamic>;
  }

  /// Supprime une entrée de la liste (par son id d'entrée).
  Future<void> deleteEntry(int entryId) async {
    final result = await _client.mutate(
      MutationOptions(
        document: gql(WatchlistMutations.deleteEntry),
        variables: {'id': entryId},
      ),
    );

    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.firstOrNull?.message
          ?? 'Impossible de supprimer l\'entrée';
      throw Exception(msg);
    }
  }
}
