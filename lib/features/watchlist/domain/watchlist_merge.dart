import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/media_list_entry.dart';

/// Calcule les entrées à écrire pour fusionner [incoming] dans [current].
///
/// Règles (on ne supprime jamais rien) :
/// - média absent de [current] → ajouté ;
/// - média présent des deux côtés → la version la plus récente (`updatedAt`,
///   une entrée sans date étant considérée comme la plus ancienne) sert de
///   base, et ses champs vides sont complétés par l'autre version
///   (voir [mergeEntryFields]).
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
    final merged = incomingIsNewer
        ? mergeEntryFields(newer: entry, older: existing)
        : mergeEntryFields(newer: existing, older: entry);

    if (!_sameContent(merged, existing)) writes[id] = merged;
  }

  return writes.values.toList();
}

/// Fusion champ par champ : la version [newer] fait foi, mais un champ vide
/// n'efface jamais une info présente dans [older].
/// - ❤️ : gardé s'il est présent d'un côté ;
/// - note / progression : celle de [newer], sinon celle de [older] ;
/// - statut : celui de [newer], sauf « À voir » si [older] est plus avancé.
///
/// Suppressions : une suppression plus récente l'emporte telle quelle ; une
/// modification plus récente qu'une suppression fait revenir le média, sans
/// reprendre les anciennes infos de la version supprimée.
GuestWatchlistEntry mergeEntryFields({
  required GuestWatchlistEntry newer,
  required GuestWatchlistEntry older,
}) {
  if (newer.deleted || older.deleted) return newer;

  final status =
      newer.status == ListStatus.planning && older.status != ListStatus.planning
          ? older.status
          : newer.status;

  return GuestWatchlistEntry(
    animeId: newer.animeId,
    title: newer.title,
    coverImage: newer.coverImage ?? older.coverImage,
    status: status,
    score: (newer.score ?? 0) > 0 ? newer.score : older.score,
    progress: (newer.progress ?? 0) > 0 ? newer.progress : older.progress,
    episodes: newer.episodes ?? older.episodes,
    mediaType: newer.mediaType,
    genres: newer.genres ?? older.genres,
    duration: newer.duration ?? older.duration,
    favourite: newer.favourite || older.favourite,
    updatedAt: newer.updatedAt,
  );
}

bool _sameContent(GuestWatchlistEntry a, GuestWatchlistEntry b) =>
    a.status == b.status &&
    a.score == b.score &&
    a.progress == b.progress &&
    a.episodes == b.episodes &&
    a.coverImage == b.coverImage &&
    a.genres?.join('|') == b.genres?.join('|') &&
    a.duration == b.duration &&
    a.favourite == b.favourite &&
    a.deleted == b.deleted;
