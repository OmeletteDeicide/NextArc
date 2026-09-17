import 'package:cloud_firestore/cloud_firestore.dart';

/// Gère la sous-collection Firestore users/{uid}/reviews/{mediaId}.
/// Chaque document contient uniquement la note textuelle personnelle.
class FirestoreReviewRepository {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviewsRef(String uid) =>
      _db.collection('users').doc(uid).collection('reviews');

  /// Stream temps-réel de la note pour un média.
  Stream<String?> watchNote(String uid, int mediaId) {
    return _reviewsRef(uid).doc(mediaId.toString()).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?['note'] as String?;
    });
  }

  /// Enregistre (crée ou écrase) la note.
  Future<void> saveNote(String uid, int mediaId, String note) async {
    await _reviewsRef(uid).doc(mediaId.toString()).set({
      'mediaId': mediaId,
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Supprime la note.
  Future<void> deleteNote(String uid, int mediaId) async {
    await _reviewsRef(uid).doc(mediaId.toString()).delete();
  }
}
