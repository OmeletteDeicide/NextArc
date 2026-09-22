import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

/// Durée pendant laquelle un titre retiré peut être restauré.
const Duration kRemovedHistoryRetention = Duration(days: 30);

/// Nombre maximum de titres gardés dans l'historique d'une liste.
const int kRemovedHistoryMax = 100;

/// Titre retiré de la liste, avec tout ce qu'il faut pour le remettre tel
/// qu'il était (statut, progression, note, ❤️, rappel d'épisodes).
class RemovedEntry {
  const RemovedEntry({
    required this.entry,
    required this.removedAt,
    this.notificationsEnabled = false,
  });

  /// Entrée telle qu'elle était juste avant le retrait.
  final GuestWatchlistEntry entry;
  final DateTime removedAt;

  /// Le rappel de sortie était actif : il sera réactivé à la restauration.
  final bool notificationsEnabled;

  int get mediaId => entry.animeId;

  Map<String, dynamic> toJson() => {
        'entry': entry.toJson(),
        'removedAt': removedAt.millisecondsSinceEpoch,
        'notifications': notificationsEnabled,
      };

  /// Null si les données stockées sont illisibles.
  static RemovedEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final entry = GuestWatchlistEntry.tryParse(raw['entry']);
    final removedAt = raw['removedAt'];
    if (entry == null || removedAt is! int) return null;
    return RemovedEntry(
      entry: entry,
      removedAt: DateTime.fromMillisecondsSinceEpoch(removedAt),
      notificationsEnabled: raw['notifications'] == true,
    );
  }
}

/// Historique affichable : sans les titres trop anciens, du plus récent au
/// plus ancien, limité à [kRemovedHistoryMax].
List<RemovedEntry> pruneRemovedHistory(
  Iterable<RemovedEntry> entries, {
  required DateTime now,
}) {
  final cutoff = now.subtract(kRemovedHistoryRetention);
  final kept = entries.where((e) => e.removedAt.isAfter(cutoff)).toList()
    ..sort((a, b) => b.removedAt.compareTo(a.removedAt));
  return kept.take(kRemovedHistoryMax).toList();
}

/// Entrée à écrire pour restaurer un titre : l'état d'avant le retrait, daté
/// de maintenant pour passer devant toute version plus ancienne.
GuestWatchlistEntry restoredEntry(RemovedEntry removed, {required DateTime now}) =>
    removed.entry.copyWith(deleted: false, updatedAt: now);

/// Le titre a été réajouté depuis son retrait : restaurer écraserait ce que
/// l'utilisateur y a mis entre-temps.
bool restoreWouldOverwrite(
  RemovedEntry removed,
  Iterable<GuestWatchlistEntry> currentList,
) =>
    currentList.any((e) => e.animeId == removed.mediaId && !e.deleted);
