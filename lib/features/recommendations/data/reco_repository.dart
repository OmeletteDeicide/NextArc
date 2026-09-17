import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/data/reco_queries.dart';

class RecoRepository {
  /// Titres recommandés par la communauté AniList pour un média donné,
  /// du mieux noté au moins bien noté. Liste vide en cas d'erreur.
  Future<List<MediaModel>> getRecommendations(int mediaId) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(RecoQueries.animeRecommendations),
        variables: {'id': mediaId},
      ),
    );

    if (result.hasException || result.data == null) return [];

    final nodes =
        result.data!['Media']?['recommendations']?['nodes'] as List<dynamic>?;
    if (nodes == null) return [];

    return [
      for (final node in nodes)
        if ((node as Map<String, dynamic>)['mediaRecommendation']
            case final Map<String, dynamic> json)
          MediaModel.fromJson(json),
    ];
  }
}
