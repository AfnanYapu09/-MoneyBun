import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

/// Shared design tokens for the soft-terracotta system (radii, spacing, shadow).
class Tokens {
  const Tokens._();

  /// Base spacing grid.
  static const double unit = 8;

  /// Horizontal screen padding.
  static const double screenPad = 20;

  // Corner radii.
  static const double rCard = 20; // cards 18–24
  static const double rCardLg = 24; // hero / spending card
  static const double rInput = 16; // inputs & buttons
  static const double rFab = 20;
  static const double rSheet = 26; // bottom-sheet top corners
  static const double rChip = 11; // small icon chips
  static const double rPill = 999; // pills / chips

  static const BorderRadius card = BorderRadius.all(Radius.circular(rCard));
  static const BorderRadius cardLg = BorderRadius.all(Radius.circular(rCardLg));
  static const BorderRadius input = BorderRadius.all(Radius.circular(rInput));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(rPill));
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(rSheet));

  /// Flat 1px card/divider border (no shadow — the signature flat look).
  static Border hairline([Color color = AppColors.line]) =>
      Border.all(color: color, width: 1);

  /// Soft FAB shadow (`0 12px 24px -6px rgba(169,84,58,.6)`).
  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: AppColors.terraDeep.withValues(alpha: 0.6),
      offset: const Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -6,
    ),
  ];

  /// Subtle lift for the active segmented-control pill.
  static List<BoxShadow> segmentShadow = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.12),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];
}

/// Builds the app [ThemeData]. [accent] customises the primary color
/// (Settings → Theme); defaults to terracotta.
class AppTheme {
  const AppTheme._();

  static ThemeData light({Color accent = AppColors.terra}) {
    const palette = AppPalette.light;
    final scheme = ColorScheme.light(
      primary: accent,
      onPrimary: AppColors.reverse,
      secondary: AppColors.terraDeep,
      onSecondary: AppColors.reverse,
      surface: palette.surface,
      onSurface: palette.ink,
      onSurfaceVariant: palette.ink2,
      outline: palette.line,
      error: AppColors.danger,
      onError: AppColors.reverse,
    );
    return _base(scheme, palette.bg, palette.ink, palette);
  }

  static ThemeData dark({Color accent = AppColors.terra}) {
    const palette = AppPalette.dark;
    final scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: AppColors.reverse,
      secondary: AppColors.terraTint,
      onSecondary: AppColors.ink,
      surface: palette.surface,
      onSurface: palette.ink,
      onSurfaceVariant: palette.ink2,
      outline: palette.line,
      error: palette.dangerFg,
      onError: AppColors.ink,
    );
    return _base(scheme, palette.bg, palette.ink, palette);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color scaffold,
    Color onBg,
    AppPalette palette,
  ) {
    final lineColor = palette.line;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: scaffold,
      textTheme: AppTypography.textTheme().apply(
        bodyColor: onBg,
        displayColor: onBg,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.heading(
          size: 18,
          weight: FontWeight.w600,
          color: onBg,
        ),
        iconTheme: IconThemeData(color: onBg),
      ),
      dividerTheme: DividerThemeData(color: lineColor, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: onBg),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Tokens.card,
          side: BorderSide(color: lineColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: AppColors.ink.withValues(alpha: 0.38),
        shape: const RoundedRectangleBorder(borderRadius: Tokens.sheetTop),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Tokens.card),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : palette.toggleOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: AppTypography.body(size: 15, color: palette.ink3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: Tokens.input,
          borderSide: BorderSide(color: lineColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Tokens.input,
          borderSide: BorderSide(color: lineColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Tokens.input,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}
