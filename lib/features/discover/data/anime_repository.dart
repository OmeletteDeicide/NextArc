import 'dart:convert';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nextarc/core/config/anilist_client.dart';
import 'package:nextarc/core/constants/app_constants.dart';
import 'package:nextarc/core/domain/paginated_result.dart';
import 'package:nextarc/core/utils/hive_cache.dart';
import 'package:nextarc/core/utils/season_helper.dart';
import 'package:nextarc/features/discover/data/anilist_queries.dart';

/// Repository principal pour les données AniList publiques.
/// Toutes les erreurs remontent via des exceptions typées.
class AnimeRepository {
  AnimeRepository({GraphQLClient? client})
      : _client = client ?? AnilistClient.instance;

  final GraphQLClient _client;

  // ── 1. Anime tendance ──────────────────────────────────────────────────────

  Future<PaginatedResult> getTrending({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
  }) async {
    const cacheKey = 'trending_p1';

    // Lecture cache (TTL 30 min)
    final cached = HiveCache.read<String>(cacheKey);
    if (cached != null) {
      return PaginatedResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(AnilistQueries.trendingAnime),
        variables: {'page': page, 'perPage': perPage},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    _checkErrors(result);
    final data = result.data!['Page'] as Map<String, dynamic>;

    // Écriture cache
    await HiveCache.write(cacheKey, jsonEncode(data), ttlMinutes: 30);

    return PaginatedResult.fromJson(data);
  }

  // ── 2. Anime de la saison en cours ─────────────────────────────────────────

  Future<PaginatedResult> getCurrentSeason({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
    String? season,
    int? year,
  }) async {
    final s = season ?? SeasonHelper.getCurrentSeason();
    final y = year ?? SeasonHelper.getCurrentYear();
    final cacheKey = 'seasonal_${s}_${y}_p$page';

    // Lecture cache (TTL 60 min — la saison change rarement)
    final cached = HiveCache.read<String>(cacheKey);
    if (cached != null) {
      return PaginatedResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(AnilistQueries.seasonalAnime),
        variables: {
          'season': s,
          'seasonYear': y,
          'page': page,
          'perPage': perPage,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    _checkErrors(result);
    final data = result.data!['Page'] as Map<String, dynamic>;

    // Écriture cache
    await HiveCache.write(cacheKey, jsonEncode(data), ttlMinutes: 60);

    return PaginatedResult.fromJson(data);
  }

  // ── 3. Manga tendance ─────────────────────────────────────────────────────

  Future<PaginatedResult> getTrendingManga({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
  }) async {
    const cacheKey = 'trending_manga_p1';

    final cached = HiveCache.read<String>(cacheKey);
    if (cached != null) {
      return PaginatedResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(AnilistQueries.trendingManga),
        variables: {'page': page, 'perPage': perPage},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    _checkErrors(result);
    final data = result.data!['Page'] as Map<String, dynamic>;
    await HiveCache.write(cacheKey, jsonEncode(data), ttlMinutes: 30);
    return PaginatedResult.fromJson(data);
  }

  // ── 4. Manga en cours de publication ──────────────────────────────────────

  Future<PaginatedResult> getReleasingManga({
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
  }) async {
    const cacheKey = 'releasing_manga_p1';

    final cached = HiveCache.read<String>(cacheKey);
    if (cached != null) {
      return PaginatedResult.fromJson(
          jsonDecode(cached) as Map<String, dynamic>);
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(AnilistQueries.releasingManga),
        variables: {'page': page, 'perPage': perPage},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    _checkErrors(result);
    final data = result.data!['Page'] as Map<String, dynamic>;
    await HiveCache.write(cacheKey, jsonEncode(data), ttlMinutes: 30);
    return PaginatedResult.fromJson(data);
  }

  // ── 5. Recherche par titre ─────────────────────────────────────────────────

  Future<PaginatedResult> searchAnime({
    required String query,
    int page = 1,
    int perPage = AppConstants.defaultPageSize,
  }) async {
    if (query.trim().isEmpty) {
      return const PaginatedResult(
        items: [],
        currentPage: 1,
        lastPage: 1,
        hasNextPage: false,
        total: 0,
      );
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(AnilistQueries.searchAnime),
        variables: {
          'search': query.trim(),
          'page': page,
          'perPage': perPage,
        },
        // Pas de cache pour la recherche — résultats différents à chaque requête
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    _checkErrors(result);
    final data = result.data!['Page'] as Map<String, dynamic>;
    return PaginatedResult.fromJson(data);
  }

  // ── Gestion d'erreurs ──────────────────────────────────────────────────────

  void _checkErrors(QueryResult result) {
    if (result.hasException) {
      final linkException = result.exception?.linkException;
      final graphqlErrors = result.exception?.graphqlErrors;

      if (linkException != null) {
        throw AnimeNetworkException(
          'Impossible de contacter AniList. Vérifie ta connexion.',
        );
      }

      if (graphqlErrors != null && graphqlErrors.isNotEmpty) {
        throw AnimeGraphQLException(
          graphqlErrors.map((e) => e.message).join(', '),
        );
      }

      throw AnimeUnknownException('Erreur inconnue.');
    }

    if (result.data == null) {
      throw AnimeUnknownException('Aucune donnée reçue d\'AniList.');
    }
  }
}

// ── Exceptions typées ──────────────────────────────────────────────────────────

class AnimeNetworkException implements Exception {
  const AnimeNetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AnimeGraphQLException implements Exception {
  const AnimeGraphQLException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AnimeUnknownException implements Exception {
  const AnimeUnknownException(this.message);
  final String message;
  @override
  String toString() => message;
}
