import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Shared pixel-style design tokens.
class PixelTokens {
  const PixelTokens._();

  /// Base spacing grid.
  static const double unit = 8;

  /// Chunky pixel border width.
  static const double border = 2.5;

  /// Hard (un-blurred) drop shadow offset.
  static const Offset shadowOffset = Offset(4, 4);

  /// Square-ish corners — small, never pill-shaped, to keep the pixel look.
  static const Radius radius = Radius.circular(4);
  static const BorderRadius borderRadius = BorderRadius.all(radius);

  /// A hard, offset, non-blurred shadow (the signature pixel look).
  static List<BoxShadow> hardShadow({Color color = AppColors.ink}) => [
        BoxShadow(color: color, offset: shadowOffset, blurRadius: 0),
      ];

  static Border inkBorder({Color color = AppColors.ink, double? width}) =>
      Border.all(color: color, width: width ?? border);
}

/// Builds the app [ThemeData] for the pixel aesthetic.
class PixelTheme {
  const PixelTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.bunOrange,
      onPrimary: AppColors.white,
      secondary: AppColors.orangeDark,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      error: AppColors.expense,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: AppTypography.textTheme(),
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.orangeLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.body(
          size: 20,
          weight: FontWeight.w800,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.gray200,
        thickness: 1.5,
        space: 1.5,
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      cardTheme: const CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: PixelTokens.borderRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: PixelTokens.borderRadius,
          borderSide:
              const BorderSide(color: AppColors.ink, width: PixelTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: PixelTokens.borderRadius,
          borderSide:
              const BorderSide(color: AppColors.ink, width: PixelTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: PixelTokens.borderRadius,
          borderSide: const BorderSide(
              color: AppColors.bunOrange, width: PixelTokens.border),
        ),
      ),
    );
  }
}
