import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

/// Calcule les entrées à écrire pour fusionner [incoming] dans [current].
///
/// Règles (on ne supprime jamais rien) :
/// - média absent de [current] → ajouté ;
/// - média présent des deux côtés → la version la plus récente (`updatedAt`)
///   gagne ; une entrée entrante sans date ne remplace jamais l'existante ;
/// - un ❤️ n'est jamais perdu, quelle que soit la version retenue.
List<GuestWatchlistEntry> computeMergeWrites(
  Map<int, GuestWatchlistEntry> current,
  Iterable<GuestWatchlistEntry> incoming,
) {
  final writes = <int, GuestWatchlistEntry>{};

  for (final entry in incoming) {
    final id = entry.animeId;
    final existing = writes[id] ?? current[id];

    if (existing == null) {
      writes[id] = entry;
      continue;
    }

    final incomingIsNewer = entry.updatedAt != null &&
        (existing.updatedAt == null ||
            entry.updatedAt!.isAfter(existing.updatedAt!));
    final favourite = entry.favourite || existing.favourite;

    if (incomingIsNewer) {
      writes[id] = entry.copyWith(favourite: favourite);
    } else if (favourite && !existing.favourite) {
      writes[id] = existing.copyWith(favourite: true);
    }
  }

  return writes.values.toList();
}
