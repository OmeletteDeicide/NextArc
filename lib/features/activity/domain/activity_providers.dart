import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/features/activity/data/activity_repository.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/auth/domain/auth_providers.dart';

final activityRepositoryProvider = Provider((_) => ActivityRepository());

/// Récap d'un mois (`yyyy-MM`) pour l'utilisateur courant.
/// Vide pour un compte AniList sans compte NextArc (pas de journal).
/// Invalidé par les notifiers de liste après chaque activité enregistrée.
final monthlyRecapProvider =
    FutureProvider.family<MonthlyRecap, String>((ref, month) async {
  final user = (await ref.watch(authProvider.future)).user;
  if (user?.usesAnilistList == true) {
    return MonthlyRecap.fromItems(month, const []);
  }

  final items = await ref
      .read(activityRepositoryProvider)
      .getMonth(uid: user?.firebaseUid, month: month);
  return MonthlyRecap.fromItems(month, items);
});
