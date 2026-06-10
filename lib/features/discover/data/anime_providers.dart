import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/discover/data/anime_repository.dart';

/// Provider du repository — injecté dans toute l'app via Riverpod.
final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(),
);
