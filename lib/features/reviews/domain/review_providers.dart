import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';
import 'package:nextarc/features/reviews/data/firestore_review_repository.dart';

final firestoreReviewRepositoryProvider =
    Provider((_) => FirestoreReviewRepository());

/// Stream de la note personnelle pour un média donné.
/// Retourne null si pas de note ou si l'utilisateur n'a pas de compte Firebase.
final reviewNoteProvider =
    StreamProvider.family<String?, int>((ref, mediaId) {
  final uid = ref
      .watch(authProvider)
      .whenOrNull(data: (a) => a.user?.firebaseUid);
  if (uid == null) return Stream.value(null);
  return ref
      .read(firestoreReviewRepositoryProvider)
      .watchNote(uid, mediaId);
});
