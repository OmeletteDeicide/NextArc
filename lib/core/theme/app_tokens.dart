import 'package:flutter/material.dart';

/// Couleurs du design system « Arc Nocturne » (design/PLAN_REFONTE.md §05).
/// Une instance par thème, exposée via `Theme.of(context).extension`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.base,
    required this.surface1,
    required this.surface2,
    required this.accent,
    required this.accentText,
    required this.violet,
    required this.star,
    required this.statusCurrent,
    required this.statusCompletedText,
    required this.statusDroppedText,
    required this.favourite,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.border,
    required this.navBar,
  });

  /// Fond des écrans.
  final Color base;

  /// Cartes.
  final Color surface1;

  /// Chips, boutons secondaires, pistes de barres.
  final Color surface2;

  /// Accent pour les fonds (boutons, barres).
  final Color accent;

  /// Accent pour le texte (contraste AA).
  final Color accentText;

  /// Fin du dégradé accent.
  final Color violet;

  /// Étoile de note.
  final Color star;

  /// Statut « En cours ».
  final Color statusCurrent;

  /// Texte de la chip « Terminé ».
  final Color statusCompletedText;

  /// Texte de la chip « Abandonné ».
  final Color statusDroppedText;

  /// Favori ❤️ et actions destructives.
  final Color favourite;

  /// Texte principal.
  final Color text1;

  /// Texte secondaire (≥ 4,5:1).
  final Color text2;

  /// Texte atténué (onglets inactifs, placeholders).
  final Color text3;

  /// Bordures et séparateurs.
  final Color border;

  /// Fond de la barre de navigation basse.
  final Color navBar;

  /// Dégradé accent — réservé au badge de titre, au CTA primaire et aux
  /// barres de progression. Jamais en fond de carte.
  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, violet],
      );

  static const dark = AppColors(
    base: Color(0xFF060A15),
    surface1: Color(0xFF0B1226),
    surface2: Color(0xFF131C36),
    accent: Color(0xFF6D8BFF),
    accentText: Color(0xFF7C93FF),
    violet: Color(0xFF8B5CF6),
    star: Color(0xFFFFC145),
    statusCurrent: Color(0xFF3DD68C),
    statusCompletedText: Color(0xFF9CB0FF),
    statusDroppedText: Color(0xFFFF8A9B),
    favourite: Color(0xFFFF5C72),
    text1: Color(0xFFEDF1FF),
    text2: Color(0xFF94A1C4),
    text3: Color(0xFF66739A),
    border: Color(0x14FFFFFF), // blanc 8 %
    navBar: Color(0xEB060A15), // base 92 %
  );

  static const light = AppColors(
    base: Color(0xFFF3F6FD),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFE6ECFA),
    accent: Color(0xFF4560E0),
    accentText: Color(0xFF3A52C9),
    violet: Color(0xFF7040E8),
    star: Color(0xFFB37700),
    statusCurrent: Color(0xFF0E8F58),
    statusCompletedText: Color(0xFF3A52C9),
    statusDroppedText: Color(0xFFD32444),
    favourite: Color(0xFFD32444),
    text1: Color(0xFF0C1226),
    text2: Color(0xFF5A6480),
    text3: Color(0xFF7A849E),
    border: Color(0x170C1226), // encre 9 %
    navBar: Color(0xFFFFFFFF),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? base,
    Color? surface1,
    Color? surface2,
    Color? accent,
    Color? accentText,
    Color? violet,
    Color? star,
    Color? statusCurrent,
    Color? statusCompletedText,
    Color? statusDroppedText,
    Color? favourite,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? border,
    Color? navBar,
  }) =>
      AppColors(
        base: base ?? this.base,
        surface1: surface1 ?? this.surface1,
        surface2: surface2 ?? this.surface2,
        accent: accent ?? this.accent,
        accentText: accentText ?? this.accentText,
        violet: violet ?? this.violet,
        star: star ?? this.star,
        statusCurrent: statusCurrent ?? this.statusCurrent,
        statusCompletedText: statusCompletedText ?? this.statusCompletedText,
        statusDroppedText: statusDroppedText ?? this.statusDroppedText,
        favourite: favourite ?? this.favourite,
        text1: text1 ?? this.text1,
        text2: text2 ?? this.text2,
        text3: text3 ?? this.text3,
        border: border ?? this.border,
        navBar: navBar ?? this.navBar,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      base: l(base, other.base),
      surface1: l(surface1, other.surface1),
      surface2: l(surface2, other.surface2),
      accent: l(accent, other.accent),
      accentText: l(accentText, other.accentText),
      violet: l(violet, other.violet),
      star: l(star, other.star),
      statusCurrent: l(statusCurrent, other.statusCurrent),
      statusCompletedText: l(statusCompletedText, other.statusCompletedText),
      statusDroppedText: l(statusDroppedText, other.statusDroppedText),
      favourite: l(favourite, other.favourite),
      text1: l(text1, other.text1),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      border: l(border, other.border),
      navBar: l(navBar, other.navBar),
    );
  }
}

/// Échelle d'espacements (multiples de 4).
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Marge horizontale des écrans.
  static const double screen = 18;

  /// Cible tactile minimale.
  static const double minTouch = 44;
}

/// Rayons d'arrondi.
abstract final class AppRadius {
  static const double chip = 8;
  static const double cover = 12;
  static const double card = 14;
  static const double sheet = 18;
  static const double full = 999;
}

/// Durées d'animation — rien au-dessus de 400 ms.
abstract final class AppMotion {
  static const press = Duration(milliseconds: 120);
  static const transition = Duration(milliseconds: 220);
  static const progress = Duration(milliseconds: 400);
}
