import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

/// Gère la sous-collection Firestore users/{uid}/watchlist/{mediaId}.
class FirestoreWatchlistRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _watchlistRef(String uid) =>
      _db.collection('users').doc(uid).collection('watchlist');

  /// Stream temps-réel de la watchlist de l'utilisateur.
  Stream<List<GuestWatchlistEntry>> watchEntries(String uid) {
    return _watchlistRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GuestWatchlistEntry.fromJson(doc.data()))
              .toList(),
        );
  }

  /// Crée ou met à jour une entrée.
  Future<void> upsertEntry(String uid, GuestWatchlistEntry entry) async {
    final data = entry.toJson()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _watchlistRef(uid)
        .doc(entry.animeId.toString())
        .set(data, SetOptions(merge: true));
  }

  /// Supprime une entrée.
  Future<void> removeEntry(String uid, int mediaId) async {
    await _watchlistRef(uid).doc(mediaId.toString()).delete();
  }
}
