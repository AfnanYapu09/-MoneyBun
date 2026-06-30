import 'package:flutter/material.dart';

import 'colors.dart';

/// Theme-aware surface/text/tint tokens for the soft-terracotta design system.
///
/// [AppColors] holds the *fixed* brand palette (terracotta, the on-accent
/// [AppColors.reverse], …). The tokens here are the ones that must change
/// between light and dark mode — backgrounds, paper surfaces, ink text, hairline
/// borders and the tinted icon-chip washes. Read them in a widget with
/// `context.palette` so every screen repaints correctly when the user switches
/// Settings → Theme.
///
/// The [light] values are byte-identical to the original [AppColors] constants,
/// so light mode looks exactly as before; [dark] is a warm, low-glare set tuned
/// for the same layout.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.toggleOff,
    required this.pixelTile,
    required this.terraWash,
    required this.terraFg,
    required this.greenTint,
    required this.greenFg,
    required this.amberWash,
    required this.amberFg,
    required this.dangerWash,
    required this.dangerFg,
  });

  /// Screen / scaffold background (was [AppColors.cream]).
  final Color bg;

  /// Cards, inputs, sheets (was [AppColors.paper]).
  final Color surface;

  /// Segmented-control track, progress track (was [AppColors.paper2]).
  final Color surfaceAlt;

  /// Primary text & icons (was [AppColors.ink]).
  final Color ink;

  /// Secondary text (was [AppColors.ink2]).
  final Color ink2;

  /// Tertiary / muted / placeholder text (was [AppColors.ink3]).
  final Color ink3;

  /// Hairline borders & dividers (was [AppColors.line]).
  final Color line;

  /// Off-state switch track (was [AppColors.toggleOff]).
  final Color toggleOff;

  /// Disc behind a full-colour pixel-art icon (was [AppColors.pixelTile]).
  final Color pixelTile;

  /// Tinted icon-chip background + its icon foreground (terracotta family).
  final Color terraWash;
  final Color terraFg;

  /// Positive / income tint background + foreground.
  final Color greenTint;
  final Color greenFg;

  /// Transfer (ย้ายเงิน) tint background + foreground.
  final Color amberWash;
  final Color amberFg;

  /// Danger / destructive tint background + foreground.
  final Color dangerWash;
  final Color dangerFg;

  /// Light mode — identical to the original [AppColors] tokens.
  static const AppPalette light = AppPalette(
    bg: AppColors.cream,
    surface: AppColors.paper,
    surfaceAlt: AppColors.paper2,
    ink: AppColors.ink,
    ink2: AppColors.ink2,
    ink3: AppColors.ink3,
    line: AppColors.line,
    toggleOff: AppColors.toggleOff,
    pixelTile: AppColors.pixelTile,
    terraWash: AppColors.terraWash,
    terraFg: AppColors.terra700,
    greenTint: AppColors.greenTint,
    greenFg: AppColors.green,
    amberWash: AppColors.amberWash,
    amberFg: AppColors.amber,
    dangerWash: AppColors.dangerWash,
    dangerFg: AppColors.danger,
  );

  /// Dark mode — warm charcoal surfaces with brightened tints for contrast.
  static const AppPalette dark = AppPalette(
    bg: Color(0xFF1A1714),
    surface: Color(0xFF252019),
    surfaceAlt: Color(0xFF322A20),
    ink: Color(0xFFEDE6DA),
    ink2: Color(0xFFB3A99A),
    ink3: Color(0xFF8A8174),
    line: Color(0xFF3A322A),
    toggleOff: Color(0xFF4A4136),
    pixelTile: Color(0xFFECE3D4),
    terraWash: Color(0xFF3B2A22),
    terraFg: Color(0xFFE0A488),
    greenTint: Color(0xFF21302A),
    greenFg: Color(0xFF7FB492),
    amberWash: Color(0xFF342B1A),
    amberFg: Color(0xFFE2BC63),
    dangerWash: Color(0xFF38201B),
    dangerFg: Color(0xFFE58A72),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? toggleOff,
    Color? pixelTile,
    Color? terraWash,
    Color? terraFg,
    Color? greenTint,
    Color? greenFg,
    Color? amberWash,
    Color? amberFg,
    Color? dangerWash,
    Color? dangerFg,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      line: line ?? this.line,
      toggleOff: toggleOff ?? this.toggleOff,
      pixelTile: pixelTile ?? this.pixelTile,
      terraWash: terraWash ?? this.terraWash,
      terraFg: terraFg ?? this.terraFg,
      greenTint: greenTint ?? this.greenTint,
      greenFg: greenFg ?? this.greenFg,
      amberWash: amberWash ?? this.amberWash,
      amberFg: amberFg ?? this.amberFg,
      dangerWash: dangerWash ?? this.dangerWash,
      dangerFg: dangerFg ?? this.dangerFg,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
      toggleOff: Color.lerp(toggleOff, other.toggleOff, t)!,
      pixelTile: Color.lerp(pixelTile, other.pixelTile, t)!,
      terraWash: Color.lerp(terraWash, other.terraWash, t)!,
      terraFg: Color.lerp(terraFg, other.terraFg, t)!,
      greenTint: Color.lerp(greenTint, other.greenTint, t)!,
      greenFg: Color.lerp(greenFg, other.greenFg, t)!,
      amberWash: Color.lerp(amberWash, other.amberWash, t)!,
      amberFg: Color.lerp(amberFg, other.amberFg, t)!,
      dangerWash: Color.lerp(dangerWash, other.dangerWash, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
    );
  }
}

/// `context.palette.ink` — the theme-aware design tokens for the current theme.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
