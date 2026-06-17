import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography for the pixel aesthetic.
///
/// IMPORTANT: pixel display fonts (Press Start 2P) have NO Thai glyphs, so they
/// are used ONLY for Latin/numeric accents (titles, big numbers). All real
/// content — especially Thai — uses Noto Sans Thai, which renders Thai + Latin.
class AppTypography {
  const AppTypography._();

  /// Body / content font. Safe for Thai.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
  }) =>
      GoogleFonts.notoSansThai(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Pixel display font. ONLY use for Latin letters / digits, never Thai text.
  static TextStyle pixel({
    double size = 12,
    Color color = AppColors.ink,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.pressStart2p(
        fontSize: size,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextTheme textTheme() {
    final base = GoogleFonts.notoSansThaiTextTheme();
    return base.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
  }
}
