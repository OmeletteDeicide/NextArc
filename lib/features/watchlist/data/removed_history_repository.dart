import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:nextarc/features/watchlist/domain/removed_history.dart';

/// Historique des titres retirés, gardé sur l'appareil (Hive). Une clé par
/// liste et par titre : `guest:123` ou `<uid>:123`. Un nouveau retrait du même
/// titre remplace l'ancien.
class RemovedHistoryRepository {
  static const _boxName = 'removed_history';

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  String _key(String owner, int mediaId) => '$owner:$mediaId';

  Future<void> record(String owner, RemovedEntry removed) async {
    final box = await _box();
    await box.put(_key(owner, removed.mediaId), jsonEncode(removed.toJson()));
    await _prune(box, owner);
  }

  /// Titres restaurables de la liste [owner], du plus récent au plus ancien.
  Future<List<RemovedEntry>> list(String owner) async {
    final box = await _box();
    await _prune(box, owner);
    return pruneRemovedHistory(_entries(box, owner).values, now: DateTime.now());
  }

  Future<RemovedEntry?> find(String owner, int mediaId) async {
    final raw = (await _box()).get(_key(owner, mediaId));
    return raw == null ? null : _decode(raw);
  }

  Future<void> delete(String owner, int mediaId) async {
    await (await _box()).delete(_key(owner, mediaId));
  }

  Future<void> clear(String owner) async {
    final box = await _box();
    await box.deleteAll(_entries(box, owner).keys);
  }

  Map<String, RemovedEntry> _entries(Box<String> box, String owner) => {
        for (final key in box.keys.whereType<String>())
          if (key.startsWith('$owner:')) key: ?_decode(box.get(key)),
      };

  /// Retire les titres expirés ou au-delà du plafond.
  Future<void> _prune(Box<String> box, String owner) async {
    final entries = _entries(box, owner);
    final kept = pruneRemovedHistory(entries.values, now: DateTime.now())
        .map((e) => _key(owner, e.mediaId))
        .toSet();
    final stale = [
      for (final key in box.keys.whereType<String>())
        if (key.startsWith('$owner:') && !kept.contains(key)) key,
    ];
    if (stale.isNotEmpty) await box.deleteAll(stale);
  }

  RemovedEntry? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return RemovedEntry.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
