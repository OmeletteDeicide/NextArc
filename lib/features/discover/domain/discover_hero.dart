import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/discover/domain/discover_providers.dart';
import 'package:nextarc/features/discover/domain/media_model.dart';
import 'package:nextarc/features/watchlist/domain/in_watchlist_provider.dart';

/// Nature du média mis en avant en haut de Découvrir.
enum DiscoverHeroKind {
  /// Épisode diffusé dans les prochaines 24 h.
  today,

  /// Épisode diffusé dans les 7 prochains jours.
  upcoming,

  /// Aucun épisode imminent : n°1 des tendances.
  trending,
}

class DiscoverHero {
  const DiscoverHero({required this.media, required this.kind});

  final MediaModel media;
  final DiscoverHeroKind kind;
}

/// Fenêtre dans laquelle un épisode à venir peut être mis en avant.
const discoverHeroWindow = Duration(days: 7);

/// Choisit le média mis en avant :
/// 1. un média de la liste de l'utilisateur dont l'épisode sort le plus tôt ;
/// 2. sinon, parmi [candidates], celui dont l'épisode sort le plus tôt ;
/// 3. sinon, le premier candidat (n°1 des tendances).
/// À délai égal, un média avec bannière est préféré.
DiscoverHero? pickDiscoverHero({
  required List<MediaModel> candidates,
  required Set<int> listIds,
  required DateTime now,
}) {
  if (candidates.isEmpty) return null;

  final airing = candidates.where((m) {
    final next = m.nextAiringEpisode;
    if (next == null) return false;
    final delay = next.airingAt.difference(now);
    return !delay.isNegative && delay <= discoverHeroWindow;
  }).toList()
    ..sort((a, b) {
      final byDate = a.nextAiringEpisode!.airingAt
          .compareTo(b.nextAiringEpisode!.airingAt);
      if (byDate != 0) return byDate;
      return (a.bannerImage == null ? 1 : 0)
          .compareTo(b.bannerImage == null ? 1 : 0);
    });

  final chosen = airing.where((m) => listIds.contains(m.id)).firstOrNull ??
      airing.firstOrNull;

  if (chosen == null) {
    return DiscoverHero(
      media: candidates.first,
      kind: DiscoverHeroKind.trending,
    );
  }

  final delay = chosen.nextAiringEpisode!.airingAt.difference(now);
  return DiscoverHero(
    media: chosen,
    kind: delay <= const Duration(hours: 24)
        ? DiscoverHeroKind.today
        : DiscoverHeroKind.upcoming,
  );
}

/// Délai avant diffusion, en unité lisible : (clé de traduction, valeur).
({String key, int count}) airingCountdown(Duration delay) {
  if (delay < const Duration(hours: 1)) {
    final minutes = delay.inMinutes < 1 ? 1 : delay.inMinutes;
    return (key: 'airing_in_minutes', count: minutes);
  }
  if (delay < const Duration(hours: 24)) {
    return (key: 'airing_in_hours', count: delay.inHours);
  }
  return (key: 'airing_in_days', count: (delay.inHours / 24).ceil());
}

/// Média mis en avant sur Découvrir (tendances + saison, liste en priorité).
final discoverHeroProvider = Provider<DiscoverHero?>((ref) {
  final trending =
      ref.watch(trendingAnimeProvider).whenOrNull(data: (r) => r.items) ??
          const <MediaModel>[];
  final seasonal =
      ref.watch(seasonalAnimeProvider).whenOrNull(data: (r) => r.items) ??
          const <MediaModel>[];

  final seen = <int>{};
  final candidates = [
    for (final media in [...trending, ...seasonal])
      if (seen.add(media.id)) media,
  ];

  return pickDiscoverHero(
    candidates: candidates,
    listIds: ref.watch(watchlistMediaIdsProvider),
    now: DateTime.now(),
  );
});
