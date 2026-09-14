import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

/// Gère la sous-collection Firestore users/{uid}/watchlist/{mediaId}.
class FirestoreWatchlistRepository {
  final _db = FirebaseFirestore.instance;

  /// Firestore limite un batch à 500 écritures.
  static const _batchSize = 400;

  CollectionReference<Map<String, dynamic>> _watchlistRef(String uid) =>
      _db.collection('users').doc(uid).collection('watchlist');

  /// L'entrée est écrite en entier (pas de merge) pour qu'un champ remis à
  /// zéro (note, progression) disparaisse vraiment. `updatedAt` est toujours
  /// l'heure serveur — les règles Firestore l'exigent.
  Map<String, dynamic> _toFirestore(GuestWatchlistEntry entry) =>
      entry.toJson()..['updatedAt'] = FieldValue.serverTimestamp();

  /// Stream temps-réel de la watchlist affichée (entrées supprimées masquées).
  Stream<List<GuestWatchlistEntry>> watchEntries(String uid) {
    return _watchlistRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GuestWatchlistEntry.tryParse(doc.data()))
              .whereType<GuestWatchlistEntry>()
              .where((entry) => !entry.deleted)
              .toList(),
        );
  }

  /// Lecture ponctuelle de toute la watchlist, entrées supprimées comprises
  /// (nécessaires à la fusion), indexée par id de média.
  Future<Map<int, GuestWatchlistEntry>> getEntries(String uid) async {
    final snap = await _watchlistRef(uid).get();
    final entries = snap.docs
        .map((doc) => GuestWatchlistEntry.tryParse(doc.data()))
        .whereType<GuestWatchlistEntry>();
    return {for (final entry in entries) entry.animeId: entry};
  }

  /// Crée ou met à jour une entrée.
  Future<void> upsertEntry(String uid, GuestWatchlistEntry entry) async {
    await _watchlistRef(uid)
        .doc(entry.animeId.toString())
        .set(_toFirestore(entry));
  }

  /// Crée ou met à jour plusieurs entrées par batchs.
  Future<void> upsertMany(String uid, List<GuestWatchlistEntry> entries) async {
    for (var i = 0; i < entries.length; i += _batchSize) {
      final batch = _db.batch();
      for (final entry in entries.skip(i).take(_batchSize)) {
        batch.set(
          _watchlistRef(uid).doc(entry.animeId.toString()),
          _toFirestore(entry),
        );
      }
      await batch.commit();
    }
  }

  /// Retire une entrée de la liste (suppression douce) : les infos de
  /// l'utilisateur sont effacées, seuls restent les champs exigés par les
  /// règles, le marqueur `deleted` et `updatedAt` (date de suppression, pour
  /// que la fusion AniList ne fasse pas revenir le média).
  /// La ré-ajouter réécrit l'entrée complète, sans le marqueur.
  Future<void> removeEntry(String uid, int mediaId) async {
    await _watchlistRef(uid).doc(mediaId.toString()).update({
      'deleted': true,
      'status': 'PLANNING',
      'score': FieldValue.delete(),
      'progress': FieldValue.delete(),
      'favourite': FieldValue.delete(),
      'episodes': FieldValue.delete(),
      'coverImage': FieldValue.delete(),
      'genres': FieldValue.delete(),
      'duration': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
