import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/constants/app_constants.dart';

/// Client GraphQL pour l'API AniList (données publiques, sans authentification).
/// En Phase 4, on ajoutera le header Authorization (Bearer token OAuth).
class AnilistClient {
  AnilistClient._();

  static GraphQLClient? _instance;

  static GraphQLClient get instance {
    _instance ??= _buildClient();
    return _instance!;
  }

  static GraphQLClient _buildClient() {
    final httpLink = HttpLink(AppConstants.anilistEndpoint);

    // En Phase 4 : AuthLink viendra s'intercaler ici
    final Link link = httpLink;

    return GraphQLClient(
      link: link,
      cache: GraphQLCache(
        // Cache en mémoire — on ajoutera Hive en Phase 8 (finition)
        store: InMemoryStore(),
      ),
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.cacheFirst, // Limite les appels réseau (rate limit AniList)
        ),
      ),
    );
  }

  /// Recrée le client avec un token (appelé après login OAuth en Phase 4).
  static void setAuthToken(String token) {
    final authLink = AuthLink(getToken: () async => 'Bearer $token');
    final httpLink = HttpLink(AppConstants.anilistEndpoint);

    _instance = GraphQLClient(
      link: authLink.concat(httpLink),
      cache: GraphQLCache(store: InMemoryStore()),
      defaultPolicies: DefaultPolicies(
        query: Policies(fetch: FetchPolicy.cacheFirst),
      ),
    );
  }

  /// Réinitialise le client sans token (appelé après logout).
  static void clearAuth() {
    _instance = _buildClient();
  }
}
