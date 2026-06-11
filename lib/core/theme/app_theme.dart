import 'package:flutter/material.dart';

// ── Palette brand (Paletton Hue 242°) ─────────────────────────────────────────
const Color kBrand50  = Color(0xFF010613); // le plus foncé
const Color kBrand100 = Color(0xFF040E28);
const Color kBrand200 = Color(0xFF0F1C3F); // couleur de base
const Color kBrand300 = Color(0xFF202F59);
const Color kBrand400 = Color(0xFF364570); // le plus clair

/// Accent — bleu clair pour boutons et éléments interactifs (dark mode).
const Color kPrimaryDark = Color(0xFF5B9BD5);

/// Accent — bleu profond pour boutons et éléments interactifs (light mode).
const Color kPrimaryLight = Color(0xFF1D4E8F);

/// Étoile de score — commun aux deux thèmes.
const Color kStarColor = Color(0xFFFFC107);

class AppTheme {
  AppTheme._();

  // ── Dark — palette brand blue ──────────────────────────────────────────────

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
        surface: kBrand200,
        surfaceContainerHighest: kBrand300,
        surfaceContainerHigh: kBrand300,
        surfaceContainer: kBrand200,
        surfaceContainerLow: kBrand100,
      ),
      scaffoldBackgroundColor: kBrand100,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBrand100,
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
        color: kBrand200,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kBrand100,
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

  // ── Light — tints clairs du même Hue 242° ─────────────────────────────────

  static ThemeData get light {
    const bg      = Color(0xFFE8EDF5); // tint très clair Hue 242°
    const surface = Color(0xFFFFFFFF);
    const onBg    = Color(0xFF0F1C3F); // texte = couleur brand foncée

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
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black12,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onBg,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: onBg),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFC5CFDF)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: kPrimaryLight,
        unselectedItemColor: Color(0xFF8A97AA),
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFC5CFDF)),
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
