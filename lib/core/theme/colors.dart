import 'package:flutter/material.dart';

/// MoneyBun palette — the "soft terracotta" design system.
///
/// Tokens mirror the design handoff (`--terra`, `--cream`, `--ink`, …). The app
/// background is [cream]; cards/inputs/sheets are [paper] with a 1px [line]
/// border and no shadow. The pixel "Bun" mascot uses [terra]/[terraDeep].
class AppColors {
  const AppColors._();

  // Brand terracotta
  static const Color terra = Color(0xFFC4694A); // primary
  static const Color terraDeep = Color(0xFFA9543A); // pressed / shadow pixels
  static const Color terra700 = Color(0xFF8F4632); // icons on tinted chips
  static const Color terraWash = Color(0xFFF4E2D8); // tinted icon backgrounds
  static const Color terraTint = Color(0xFFEAD3C7); // skeleton / shimmer

  // Surfaces
  static const Color cream = Color(0xFFF1EEE4); // app / screen background
  static const Color paper = Color(0xFFFBFAF6); // cards, inputs, sheets
  static const Color paper2 = Color(0xFFEFEADC); // segmented track, progress

  // Ink (text)
  static const Color ink = Color(0xFF211C18); // primary text, eyes
  static const Color ink2 = Color(0xFF6E635A); // secondary text
  static const Color ink3 = Color(0xFFA0948A); // tertiary / placeholder / muted

  static const Color line = Color(0xFFE7E0D2); // borders, dividers
  static const Color toggleOff = Color(0xFFD8D0C2); // off-state switch track

  // Positive / income
  static const Color green = Color(0xFF4E7A5E);
  static const Color greenTint = Color(0xFFE3EDE2);

  // Transfer (ย้ายเงิน) — amber / gold
  static const Color amber = Color(0xFFBE8A1F);
  static const Color amberWash = Color(0xFFF2E8CC);

  // Text / icons on terracotta
  static const Color reverse = Color(0xFFFBF4EE);

  // Danger (over-budget bar, delete)
  static const Color danger = Color(0xFFB23F2A);
  static const Color dangerWash = Color(0xFFF3DAD2);

  // Semantic transaction directions.
  static const Color income = green; // +฿ amounts
  static const Color expense = ink; // −฿ amounts (design uses ink, not red)
  static const Color transfer = amber; // ย้ายเงิน

  /// Parse a stored `colorHex` ("FFE8732C" or "#E8732C") into a [Color].
  static Color forHex(String hex) {
    final value = hex.replaceAll('#', '');
    final withAlpha = value.length == 6 ? 'FF$value' : value;
    return Color(int.parse(withAlpha, radix: 16));
  }

  /// A soft, translucent wash of a stored `colorHex` — the tinted background
  /// behind a category emoji chip, so the full-colour emoji stays legible.
  static Color softHex(String hex, [double alpha = 0.2]) =>
      forHex(hex).withValues(alpha: alpha);

  /// A soft, translucent wash of an already-parsed [color].
  static Color soft(Color color, [double alpha = 0.2]) =>
      color.withValues(alpha: alpha);
}
