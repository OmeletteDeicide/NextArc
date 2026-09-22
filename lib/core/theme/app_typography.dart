import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Échelle typographique du design system :
/// - titres (display, h1, h2) : Audiowide, une seule graisse — grands
///   nombres, titres d'écran et de section, cartes de partage ;
/// - title : Chakra Petch 700 14/18 · body : Chakra Petch 400 13/21 ;
/// - meta : Chakra Petch 500 11/16 · overline : Chakra Petch 600 10, +14 %.
abstract final class AppTypography {
  static TextTheme textTheme({required Color text1, required Color text2}) {
    return TextTheme(
      // display
      displayLarge: _heading(36, 40 / 36, text1),
      displayMedium: _heading(28, 32 / 28, text1),
      displaySmall: _heading(28, 1.05, text1),
      // h1
      headlineMedium: _heading(24, 1.2, text1),
      headlineSmall: _heading(21, 1.2, text1),
      // h2
      titleLarge: _heading(17, 1.3, text1),
      // title
      titleMedium: GoogleFonts.chakraPetch(
          fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w700,
          color: text1),
      titleSmall: GoogleFonts.chakraPetch(
          fontSize: 13, height: 17 / 13, fontWeight: FontWeight.w700,
          color: text1),
      // body
      bodyLarge: GoogleFonts.chakraPetch(
          fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400,
          color: text1),
      bodyMedium: GoogleFonts.chakraPetch(
          fontSize: 13, height: 21 / 13, fontWeight: FontWeight.w400,
          color: text1),
      // meta
      bodySmall: GoogleFonts.chakraPetch(
          fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500,
          color: text2),
      // boutons, onglets
      labelLarge: GoogleFonts.chakraPetch(
          fontSize: 13, fontWeight: FontWeight.w700, color: text1),
      labelMedium: GoogleFonts.chakraPetch(
          fontSize: 12, fontWeight: FontWeight.w700, color: text1),
      // overline
      labelSmall: overline(text2),
    );
  }

  /// Titres en Audiowide : une seule graisse (400), jamais de gras synthétique.
  static TextStyle _heading(double size, double height, Color color) =>
      GoogleFonts.audiowide(
          fontSize: size, height: height, fontWeight: FontWeight.w400,
          color: color);

  /// Sur-titre de section en capitales (« GENRES FAVORIS »).
  static TextStyle overline(Color color) => GoogleFonts.chakraPetch(
      fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4,
      color: color);

  /// Famille par défaut de toute l'interface.
  static String? get bodyFamily => GoogleFonts.chakraPetch().fontFamily;
}
