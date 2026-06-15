import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';

class GuestWatchlistRepository {
  static const _storage = FlutterSecureStorage();
  static const _key = 'guest_watchlist';

  Future<List<GuestWatchlistEntry>> getEntries() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              GuestWatchlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntries(List<GuestWatchlistEntry> entries) async {
    final data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _key, value: data);
  }

  Future<void> upsertEntry(GuestWatchlistEntry entry) async {
    final entries = await getEntries();
    final idx = entries.indexWhere((e) => e.animeId == entry.animeId);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    await saveEntries(entries);
  }

  Future<void> removeEntry(int animeId) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.animeId == animeId);
    await saveEntries(entries);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _key);
  }

  Future<String> exportJson() async {
    final entries = await getEntries();
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }

  Future<void> importJson(String jsonStr) async {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    final entries = list
        .map((e) =>
            GuestWatchlistEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    await saveEntries(entries);
  }
}
