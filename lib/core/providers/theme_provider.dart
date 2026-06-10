import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _kThemeKey = 'app_theme_mode';

/// Notifier qui stocke le [ThemeMode] choisi par l'utilisateur.
/// Persiste la préférence dans la box Hive déjà ouverte par HiveCache.
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(_loadTheme());

  static ThemeMode _loadTheme() {
    try {
      final box = Hive.box('nextarc_cache');
      final value = box.get(_kThemeKey, defaultValue: 'system') as String;
      return switch (value) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final box = Hive.box('nextarc_cache');
    final key = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      _ => 'system',
    };
    await box.put(_kThemeKey, key);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
