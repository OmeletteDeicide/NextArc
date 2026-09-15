import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Échelle typographique du design system :
/// - display : Archivo Black 36/40 — grands nombres, cartes de partage ;
/// - h1 : Sora 800 24/28 · h2 : Sora 700 17/22 ;
/// - title : Manrope 700 14/18 · body : Manrope 400 13/21 ;
/// - meta : Manrope 500 11/16 · overline : JetBrains Mono 600 10, +14 %.
abstract final class AppTypography {
  static TextTheme textTheme({required Color text1, required Color text2}) {
    return TextTheme(
      // display
      displayLarge: GoogleFonts.archivoBlack(
          fontSize: 36, height: 40 / 36, letterSpacing: -1, color: text1),
      displayMedium: GoogleFonts.archivoBlack(
          fontSize: 28, height: 32 / 28, letterSpacing: -0.8, color: text1),
      displaySmall: GoogleFonts.sora(
          fontSize: 28, height: 1.05, fontWeight: FontWeight.w800,
          letterSpacing: -1, color: text1),
      // h1
      headlineMedium: GoogleFonts.sora(
          fontSize: 24, height: 28 / 24, fontWeight: FontWeight.w800,
          letterSpacing: -0.8, color: text1),
      headlineSmall: GoogleFonts.sora(
          fontSize: 21, height: 1.1, fontWeight: FontWeight.w800,
          letterSpacing: -0.5, color: text1),
      // h2
      titleLarge: GoogleFonts.sora(
          fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w700,
          letterSpacing: -0.4, color: text1),
      // title
      titleMedium: GoogleFonts.manrope(
          fontSize: 14, height: 18 / 14, fontWeight: FontWeight.w700,
          color: text1),
      titleSmall: GoogleFonts.manrope(
          fontSize: 13, height: 17 / 13, fontWeight: FontWeight.w700,
          color: text1),
      // body
      bodyLarge: GoogleFonts.manrope(
          fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400,
          color: text1),
      bodyMedium: GoogleFonts.manrope(
          fontSize: 13, height: 21 / 13, fontWeight: FontWeight.w400,
          color: text1),
      // meta
      bodySmall: GoogleFonts.manrope(
          fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500,
          color: text2),
      // boutons, onglets
      labelLarge: GoogleFonts.manrope(
          fontSize: 13, fontWeight: FontWeight.w800, color: text1),
      labelMedium: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w700, color: text1),
      // overline
      labelSmall: overline(text2),
    );
  }

  /// Sur-titre de section en capitales (« GENRES FAVORIS »).
  static TextStyle overline(Color color) => GoogleFonts.jetBrainsMono(
      fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4,
      color: color);

  /// Famille par défaut de toute l'interface.
  static String? get bodyFamily => GoogleFonts.manrope().fontFamily;
}
