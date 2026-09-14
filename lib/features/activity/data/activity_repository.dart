import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nextarc/features/activity/domain/month_activity.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

/// Journal d'activité mensuel (récap du mois).
/// - Compte NextArc : `users/{uid}/activity/{yyyy-MM}` ;
/// - invité (`uid` null) : stockage local, versé dans Firestore à la connexion.
class ActivityRepository {
  final _db = FirebaseFirestore.instance;
  static const _storage = FlutterSecureStorage();
  static const _guestKey = 'guest_activity';
  static const _guestStartKey = 'guest_started_at';

  /// Date de création du compte, mise en cache par uid.
  final _accountStart = <String, DateTime?>{};

  DocumentReference<Map<String, dynamic>> _monthRef(String uid, String month) =>
      _db.collection('users').doc(uid).collection('activity').doc(month);

  /// Vrai pendant la [libraryPhase] qui suit la création du compte (ou le
  /// premier usage en invité).
  Future<bool> isInLibraryPhase(String? uid) async {
    final now = DateTime.now();
    DateTime? start;

    if (uid == null) {
      final ms = int.tryParse(await _storage.read(key: _guestStartKey) ?? '');
      if (ms == null) {
        await _storage.write(
            key: _guestStartKey, value: now.millisecondsSinceEpoch.toString());
        return true;
      }
      start = DateTime.fromMillisecondsSinceEpoch(ms);
    } else {
      if (!_accountStart.containsKey(uid)) {
        final doc = await _db.collection('users').doc(uid).get();
        _accountStart[uid] = (doc.data()?['createdAt'] as Timestamp?)?.toDate();
      }
      start = _accountStart[uid];
    }

    return start == null || now.difference(start) < libraryPhase;
  }

  /// Enregistre l'activité d'une modification de la liste (si elle compte).
  Future<void> record({
    required String? uid,
    required GuestWatchlistEntry? before,
    required GuestWatchlistEntry after,
  }) async {
    final item = computeActivity(
      before: before,
      after: after,
      inLibraryPhase: await isInLibraryPhase(uid),
    );
    if (item == null) return;
    await recordItems(uid: uid, month: monthKey(DateTime.now()), items: [item]);
  }

  /// Ajoute des activités au mois [month] (cumulées avec l'existant).
  Future<void> recordItems({
    required String? uid,
    required String month,
    required List<ActivityItem> items,
  }) async {
    if (items.isEmpty) return;

    if (uid == null) {
      final months = await _readGuest();
      final media = months.putIfAbsent(month, () => {});
      for (final item in items) {
        final existing = media[item.mediaId];
        media[item.mediaId] = existing?.accumulate(item) ?? item;
      }
      await _writeGuest(months);
      return;
    }

    // Merge : les compteurs s'additionnent côté serveur (FieldValue.increment)
    await _monthRef(uid, month).set({
      'month': month,
      'updatedAt': FieldValue.serverTimestamp(),
      'media': {
        for (final item in items)
          '${item.mediaId}': item.toMap()
            ..['progressAdded'] = FieldValue.increment(item.progressAdded),
      },
    }, SetOptions(merge: true));
  }

  /// Retire un média supprimé du récap du mois en cours.
  Future<void> removeFromCurrentMonth({
    required String? uid,
    required int mediaId,
  }) async {
    final month = monthKey(DateTime.now());

    if (uid == null) {
      final months = await _readGuest();
      if (months[month]?.remove(mediaId) != null) await _writeGuest(months);
      return;
    }

    try {
      await _monthRef(uid, month).update({
        'media.$mediaId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'not-found') rethrow; // pas d'activité ce mois-ci
    }
  }

  /// Activités d'un mois.
  Future<List<ActivityItem>> getMonth({
    required String? uid,
    required String month,
  }) async {
    if (uid == null) {
      return (await _readGuest())[month]?.values.toList() ?? const [];
    }
    final doc = await _monthRef(uid, month).get();
    final media = doc.data()?['media'];
    if (media is! Map) return const [];
    return [
      for (final e in media.entries)
        ?ActivityItem.tryParse('${e.key}', e.value),
    ];
  }

  /// Verse le journal invité dans Firestore à la connexion, puis le vide.
  Future<void> mergeGuestIntoFirestore(String uid) async {
    final months = await _readGuest();
    for (final MapEntry(key: month, value: media) in months.entries) {
      await recordItems(uid: uid, month: month, items: media.values.toList());
    }
    await _storage.delete(key: _guestKey);
  }

  // ── Stockage local invité ────────────────────────────────────────────────

  Future<Map<String, Map<int, ActivityItem>>> _readGuest() async {
    final raw = await _storage.read(key: _guestKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final MapEntry(key: month, value: media) in decoded.entries)
          if (media is Map)
            month: {
              for (final item in media.entries
                  .map((e) => ActivityItem.tryParse('${e.key}', e.value))
                  .nonNulls)
                item.mediaId: item,
            },
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeGuest(Map<String, Map<int, ActivityItem>> months) async {
    await _storage.write(
      key: _guestKey,
      value: jsonEncode({
        for (final MapEntry(key: month, value: media) in months.entries)
          month: {for (final item in media.values) '${item.mediaId}': item.toMap()},
      }),
    );
  }
}
