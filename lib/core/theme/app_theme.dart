import 'package:flutter/material.dart';
import 'package:nextarc/core/theme/app_tokens.dart';
import 'package:nextarc/core/theme/app_typography.dart';

/// Étoile de score (compatibilité : préférer `AppColors.of(context).star`,
/// qui s'adapte au thème clair).
const Color kStarColor = Color(0xFFFFC145);

/// Thèmes de l'app construits depuis les tokens « Arc Nocturne »
/// (voir app_tokens.dart et design/PLAN_REFONTE.md).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = AppTypography.textTheme(text1: c.text1, text2: c.text2);

    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
    ).copyWith(
      primary: c.accentText,
      onPrimary: Colors.white,
      primaryContainer: c.surface2,
      onPrimaryContainer: c.text1,
      secondary: c.violet,
      onSecondary: Colors.white,
      secondaryContainer: c.surface2,
      onSecondaryContainer: c.text1,
      surface: c.base,
      onSurface: c.text1,
      onSurfaceVariant: c.text2,
      surfaceContainerLowest: c.base,
      surfaceContainerLow: c.surface1,
      surfaceContainer: c.surface1,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface2,
      error: c.favourite,
      outline: c.text3,
      outlineVariant: c.border,
    );

    const cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
    );
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.base,
      fontFamily: AppTypography.bodyFamily,
      textTheme: text,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.base,
        foregroundColor: c.text1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.text1),
      ),
      cardTheme: CardThemeData(
        color: c.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navBar,
        selectedItemColor: c.accentText,
        unselectedItemColor: c.text3,
        selectedLabelStyle: text.labelMedium?.copyWith(fontSize: 11),
        unselectedLabelStyle: text.labelMedium
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: c.accentText,
        textColor: c.text1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          textStyle: text.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text1,
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          side: BorderSide(color: c.border),
          textStyle: text.labelLarge,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentText,
          textStyle: text.labelMedium,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface2,
        side: BorderSide.none,
        labelStyle: text.labelMedium?.copyWith(color: c.text2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.chip)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text1,
        unselectedLabelColor: c.text3,
        indicatorColor: c.accentText,
        dividerColor: c.border,
        labelStyle: text.labelMedium,
        unselectedLabelStyle:
            text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        thumbColor: c.accent,
        inactiveTrackColor: c.surface2,
        overlayColor: c.accent.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.text3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surface2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surface2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.text2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.cover)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface1,
        hintStyle: text.bodyMedium?.copyWith(color: c.text3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cover),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cover),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.cover),
          borderSide: BorderSide(color: c.accentText, width: 1.5),
        ),
      ),
    );
  }
}
