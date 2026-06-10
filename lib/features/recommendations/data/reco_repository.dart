import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/recommendations/data/reco_queries.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';

class RecoRepository {
  /// Récupère les recommandations pour un anime donné.
  Future<List<RecommendationItem>> getRecommendationsForAnime({
    required int animeId,
    required String sourceTitle,
    Set<int> excludeIds = const {},
  }) async {
    final result = await AnilistClient.instance.query(
      QueryOptions(
        document: gql(RecoQueries.animeRecommendations),
        variables: {'id': animeId},
      ),
    );

    if (result.hasException || result.data == null) return [];

    final nodes = result.data!['Media']?['recommendations']?['nodes']
        as List<dynamic>?;
    if (nodes == null) return [];

    final items = <RecommendationItem>[];
    for (final node in nodes) {
      final mediaJson =
          (node as Map<String, dynamic>)['mediaRecommendation']
              as Map<String, dynamic>?;
      if (mediaJson == null) continue;

      final media = MediaModel.fromJson(mediaJson);
      // Exclut les anime déjà vus
      if (excludeIds.contains(media.id)) continue;

      items.add(RecommendationItem(
        sourceTitle: sourceTitle,
        recommended: media,
        rating: node['rating'] as int?,
      ));
    }

    return items;
  }
}
