import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/discover/data/anime_providers.dart';
import 'package:nextarc/features/recommendations/data/reco_repository.dart';
import 'package:nextarc/features/recommendations/domain/recommendation_model.dart';
import 'package:nextarc/features/watchlist/domain/firestore_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

final recoRepositoryProvider = Provider((_) => RecoRepository());

/// Recommandations affichées + indique si elles sont personnalisées
/// (sinon ce sont les tendances, en attendant des ❤️ ou des notes).
class RecoFeed {
  const RecoFeed({required this.items, required this.isPersonalised});

  final List<RecommendationItem> items;
  final bool isPersonalised;
}

typedef _Source = ({int id, String title});

/// Recommandations anime personnalisées ou tendances en fallback.
final recommendationsProvider =
    FutureProvider<RecoFeed>((ref) => _buildFeed(ref, isManga: false));

/// Recommandations manga personnalisées ou tendances manga en fallback.
final mangaRecommendationsProvider =
    FutureProvider<RecoFeed>((ref) => _buildFeed(ref, isManga: true));

Future<RecoFeed> _buildFeed(Ref ref, {required bool isManga}) async {
  final auth = await ref.watch(authProvider.future);
  final user = auth.user;

  // L'API de recommandations AniList est publique : il suffit des ids des
  // médias aimés, quel que soit le type de compte.
  final seenIds = <int>{};
  final sources = <_Source>[];

  if (user?.usesAnilistList == true) {
    final groups = await ref
        .watch((isManga ? userMangaListProvider : userListProvider).future);
    if (!isManga) {
      final favs = await ref.watch(userFavouritesProvider.future);
      for (final fav in favs.take(3)) {
        sources.add((id: fav.id, title: fav.displayTitle));
      }
    }
    for (final group in groups) {
      for (final entry in group.entries) {
        seenIds.add(entry.media.id);
        if ((entry.score ?? 0) >= 7 &&
            !sources.any((s) => s.id == entry.media.id)) {
          sources.add((id: entry.media.id, title: entry.media.displayTitle));
        }
      }
    }
  } else {
    final entries = user?.hasFirebase == true
        ? await ref.watch(firestoreWatchlistProvider.future)
        : await ref.watch(guestWatchlistProvider.future);
    final ofType = entries.where((e) => e.isManga == isManga).toList();
    seenIds.addAll(ofType.map((e) => e.animeId));

    int byScore(GuestWatchlistEntry a, GuestWatchlistEntry b) =>
        (b.score ?? 0).compareTo(a.score ?? 0);
    final liked = ofType.where((e) => e.favourite).toList()..sort(byScore);
    final rated = ofType
        .where((e) => !e.favourite && (e.score ?? 0) >= 7)
        .toList()
      ..sort(byScore);
    sources.addAll(
      [...liked, ...rated].map((e) => (id: e.animeId, title: e.title)),
    );
  }

  final items = await _collectRecos(
    ref.read(recoRepositoryProvider),
    sources,
    seenIds,
  );
  if (items.isNotEmpty) return RecoFeed(items: items, isPersonalised: true);

  final animeRepo = ref.read(animeRepositoryProvider);
  final trending = isManga
      ? await animeRepo.getTrendingManga(perPage: 20)
      : await animeRepo.getTrending(perPage: 20);

  return RecoFeed(
    items: trending.items
        .map((media) => RecommendationItem(sourceTitle: '', recommended: media))
        .toList(),
    isPersonalised: false,
  );
}

/// Max 3 recos par source (5 sources max), entrelacées pour diversifier.
Future<List<RecommendationItem>> _collectRecos(
  RecoRepository repo,
  List<_Source> sources,
  Set<int> seenIds,
) async {
  const maxPerSource = 3;
  final seenRecoIds = <int>{...seenIds};
  final perSource = <List<RecommendationItem>>[];

  for (final source in sources.take(5)) {
    final recos = await repo.getRecommendationsForAnime(
      animeId: source.id,
      sourceTitle: source.title,
      excludeIds: seenRecoIds,
    );
    final picked = <RecommendationItem>[];
    for (final reco in recos) {
      if (seenRecoIds.add(reco.recommended.id)) {
        picked.add(reco);
        if (picked.length >= maxPerSource) break;
      }
    }
    if (picked.isNotEmpty) perSource.add(picked);
  }

  final allRecos = <RecommendationItem>[];
  final maxRound = perSource.fold(0, (m, l) => l.length > m ? l.length : m);
  for (var i = 0; i < maxRound; i++) {
    for (final list in perSource) {
      if (i < list.length) allRecos.add(list[i]);
    }
  }
  return allRecos;
}
