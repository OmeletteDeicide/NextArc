import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_providers.dart';

/// Un épisode à venir dans le calendrier.
class AiringEntry {
  final MediaListEntry listEntry;
  final int episode;
  final DateTime airingAt;

  const AiringEntry({
    required this.listEntry,
    required this.episode,
    required this.airingAt,
  });
}

/// Map jour (date tronquée) → liste d'épisodes à diffuser ce jour.
/// Filtre les 14 prochains jours, trié par heure de diffusion.
final airingCalendarProvider =
    FutureProvider<Map<DateTime, List<AiringEntry>>>((ref) async {
  final groups = await ref.watch(userListProvider.future);

  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 14));

  final result = <DateTime, List<AiringEntry>>{};

  for (final group in groups) {
    // On inclut "En cours" et "Prévu" — les deux peuvent avoir nextAiringEpisode
    if (group.status != ListStatus.current &&
        group.status != ListStatus.planning) {
      continue;
    }

    for (final entry in group.entries) {
      final next = entry.media.nextAiringEpisode;
      if (next == null) continue;
      if (next.airingAt.isBefore(now) || next.airingAt.isAfter(cutoff)) {
        continue; // ignore hors fenêtre
      }

      final day = DateTime(
          next.airingAt.year, next.airingAt.month, next.airingAt.day);
      result.putIfAbsent(day, () => []).add(AiringEntry(
            listEntry: entry,
            episode: next.episode,
            airingAt: next.airingAt,
          ));
    }
  }

  // Trie les épisodes de chaque jour par heure
  for (final list in result.values) {
    list.sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }

  return result;
});
