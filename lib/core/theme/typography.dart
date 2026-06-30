import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Typography for the soft-terracotta design system.
///
/// Three families (all bundled in `google_fonts/`, no runtime fetch):
/// - [display] → **Fraunces** (serif) — the `moneyBun` wordmark only.
/// - [heading] → **Mitr** — headings, ฿ numbers, buttons, labels, nav.
/// - [body]    → **IBM Plex Sans Thai** — body copy, subtitles, placeholders.
///
/// Both Mitr and IBM Plex Sans Thai render Thai + Latin, so any string is safe.
class AppTypography {
  const AppTypography._();

  /// Body / content font (IBM Plex Sans Thai). Safe for Thai.
  ///
  /// [color] defaults to `null` so the text *inherits* the ambient
  /// [DefaultTextStyle] colour (the theme's `onSurface`). That is what lets
  /// every unstyled label flip to light ink in dark mode — pass an explicit
  /// colour (or a `context.palette` token) only when a specific tone is needed.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.ibmPlexSansThai(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Heading / number / button / label font (Mitr). Safe for Thai.
  ///
  /// [color] defaults to `null` (inherits the ambient text colour) — see [body].
  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.mitr(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Wordmark font (Fraunces). Latin only — used for the `moneyBun` logo.
  ///
  /// [color] defaults to `null` (inherits the ambient text colour) — see [body].
  static TextStyle display({
    double size = 30,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Default [TextTheme] — body text uses IBM Plex Sans Thai; titles use Mitr.
  static TextTheme textTheme() {
    final body = GoogleFonts.ibmPlexSansThaiTextTheme();
    final heading = GoogleFonts.mitrTextTheme();
    return body
        .copyWith(
          titleLarge: heading.titleLarge,
          titleMedium: heading.titleMedium,
          titleSmall: heading.titleSmall,
          headlineSmall: heading.headlineSmall,
          headlineMedium: heading.headlineMedium,
          labelLarge: heading.labelLarge,
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  }
}
