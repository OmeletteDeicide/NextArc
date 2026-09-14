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

  /// Stream temps-réel de la watchlist de l'utilisateur.
  Stream<List<GuestWatchlistEntry>> watchEntries(String uid) {
    return _watchlistRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GuestWatchlistEntry.tryParse(doc.data()))
              .whereType<GuestWatchlistEntry>()
              .toList(),
        );
  }

  /// Lecture ponctuelle de toute la watchlist, indexée par id de média.
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

  /// Supprime une entrée.
  Future<void> removeEntry(String uid, int mediaId) async {
    await _watchlistRef(uid).doc(mediaId.toString()).delete();
  }
}
