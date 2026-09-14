import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_entry.dart';
import 'package:nextarc/features/watchlist/domain/watchlist_merge.dart';

class GuestWatchlistRepository {
  static const _storage = FlutterSecureStorage();
  static const _key = 'guest_watchlist';

  /// Plafond d'entrées accepté à l'import d'un fichier.
  static const maxImportEntries = 5000;

  Future<List<GuestWatchlistEntry>> getEntries() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      // Une entrée corrompue est ignorée, sans faire perdre le reste de la liste
      return list
          .map(GuestWatchlistEntry.tryParse)
          .whereType<GuestWatchlistEntry>()
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
    final stamped = entry.copyWith(updatedAt: DateTime.now());
    final entries = await getEntries();
    final idx = entries.indexWhere((e) => e.animeId == entry.animeId);
    if (idx >= 0) {
      entries[idx] = stamped;
    } else {
      entries.add(stamped);
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

  /// Importe un fichier exporté : les entrées invalides sont ignorées et la
  /// liste existante est fusionnée (jamais écrasée). Retourne le nombre
  /// d'entrées ajoutées ou mises à jour.
  Future<int> importJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List) {
      throw const FormatException('Fichier de watchlist invalide');
    }
    if (decoded.length > maxImportEntries) {
      throw const FormatException(
          'Fichier trop volumineux ($maxImportEntries entrées max)');
    }

    final incoming = decoded
        .map(GuestWatchlistEntry.tryParse)
        .whereType<GuestWatchlistEntry>();
    final current = {for (final e in await getEntries()) e.animeId: e};
    final writes = computeMergeWrites(current, incoming);

    for (final entry in writes) {
      current[entry.animeId] = entry;
    }
    await saveEntries(current.values.toList());
    return writes.length;
  }
}
