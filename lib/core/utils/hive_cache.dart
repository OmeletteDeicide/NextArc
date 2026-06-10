import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Service de cache générique basé sur Hive.
///
/// Chaque entrée est stockée sous forme JSON avec un timestamp.
/// Un TTL (Time To Live) permet d'invalider les données périmées.
class HiveCache {
  static const String _boxName = 'nextarc_cache';
  static Box? _box;

  /// Initialise la box Hive (à appeler dans main.dart après Hive.initFlutter).
  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    assert(_box != null, 'HiveCache.init() must be called first');
    return _box!;
  }

  /// Écrit [data] dans le cache pour [key] avec un TTL en minutes.
  static Future<void> write(
    String key,
    dynamic data, {
    int ttlMinutes = 30,
  }) async {
    final entry = {
      'data': data,
      'expiresAt': DateTime.now()
          .add(Duration(minutes: ttlMinutes))
          .millisecondsSinceEpoch,
    };
    await _b.put(key, jsonEncode(entry));
  }

  /// Lit [key] et retourne les données si elles ne sont pas expirées.
  /// Retourne `null` si absent ou expiré.
  static T? read<T>(String key) {
    final raw = _b.get(key) as String?;
    if (raw == null) return null;

    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = entry['expiresAt'] as int;

      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        _b.delete(key); // Nettoyage automatique
        return null;
      }

      return entry['data'] as T?;
    } catch (_) {
      return null;
    }
  }

  /// Invalide une entrée spécifique.
  static Future<void> invalidate(String key) => _b.delete(key);

  /// Vide tout le cache.
  static Future<void> clear() => _b.clear();
}
