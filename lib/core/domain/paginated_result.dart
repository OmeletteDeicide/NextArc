import 'package:nextarc/features/discover/domain/media_model.dart';

/// Résultat paginé retourné par les repositories AniList.
class PaginatedResult {
  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.hasNextPage,
    required this.total,
  });

  final List<MediaModel> items;
  final int currentPage;
  final int lastPage;
  final bool hasNextPage;
  final int total;

  factory PaginatedResult.fromJson(Map<String, dynamic> pageJson) {
    final pageInfo = pageJson['pageInfo'] as Map<String, dynamic>;
    final mediaList = pageJson['media'] as List<dynamic>;

    return PaginatedResult(
      items: mediaList
          .map((e) => MediaModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: pageInfo['currentPage'] as int,
      lastPage: pageInfo['lastPage'] as int,
      hasNextPage: pageInfo['hasNextPage'] as bool,
      total: pageInfo['total'] as int,
    );
  }
}
