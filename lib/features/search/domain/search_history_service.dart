import 'package:hive_flutter/hive_flutter.dart';

/// Stocke les 10 dernières recherches en local (Hive).
class SearchHistoryService {
  static const _boxName = 'search_history';
  static const _key = 'history';
  static const _maxItems = 10;

  static SearchHistoryService? _instance;
  static SearchHistoryService get instance =>
      _instance ??= SearchHistoryService._();
  SearchHistoryService._();

  Box<String>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  List<String> get history {
    final box = _box;
    if (box == null) return [];
    return List<String>.from(box.values);
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final box = _box;
    if (box == null) return;

    // Reconstruire la liste en mettant l'entrée en tête, sans doublon
    final current = List<String>.from(box.values);
    current.remove(q);
    current.insert(0, q);

    final trimmed = current.take(_maxItems).toList();
    await box.clear();
    for (var i = 0; i < trimmed.length; i++) {
      await box.put(i, trimmed[i]);
    }
  }

  Future<void> remove(String query) async {
    final box = _box;
    if (box == null) return;
    final current = List<String>.from(box.values);
    current.remove(query);
    await box.clear();
    for (var i = 0; i < current.length; i++) {
      await box.put(i, current[i]);
    }
  }

  Future<void> clear() async => _box?.clear();
}
