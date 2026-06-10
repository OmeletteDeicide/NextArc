import 'package:flutter/material.dart';

// ── Couleurs brand ─────────────────────────────────────────────────────────────

/// Bleu denim — dark mode (assez clair pour ressortir sur fond sombre).
const Color kPrimaryDark = Color(0xFF5B9BD5);

/// Bleu denim — light mode (assez foncé pour contraste sur fond clair).
const Color kPrimaryLight = Color(0xFF1D4E8F);

/// Étoile de score — commun aux deux thèmes.
const Color kStarColor = Color(0xFFFFC107);

class AppTheme {
  AppTheme._();

  // ── Dark — Nori & bleu denim foncé ────────────────────────────────────────

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryDark,
        brightness: Brightness.dark,
      ).copyWith(
        primary: kPrimaryDark,
        onPrimary: Colors.white,
        secondary: kPrimaryDark,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D1117), // nori
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D1117),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF161C26),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0D1117),
        selectedItemColor: kPrimaryDark,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12),
      listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryDark,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: kPrimaryDark,
        thumbColor: kPrimaryDark,
        inactiveTrackColor: Colors.white12,
      ),
    );
  }

  // ── Light — Blanc doux & bleu denim ───────────────────────────────────────

  static ThemeData get light {
    const bg = Color(0xFFF0F4FA);
    const surface = Colors.white;
    const onBg = Color(0xFF1A2035);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryLight,
        brightness: Brightness.light,
      ).copyWith(
        primary: kPrimaryLight,
        onPrimary: Colors.white,
        secondary: kPrimaryLight,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: onBg,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: onBg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: onBg),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDDE5F0)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: kPrimaryLight,
        unselectedItemColor: Color(0xFF8A97AA),
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDDE5F0)),
      listTileTheme: const ListTileThemeData(iconColor: kPrimaryLight),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryLight,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: kPrimaryLight,
        thumbColor: kPrimaryLight,
        inactiveTrackColor: kPrimaryLight.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF8A97AA)),
      ),
    );
  }
}
