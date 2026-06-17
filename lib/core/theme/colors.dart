import 'package:flutter/material.dart';

/// MoneyBun palette — orange / white / gray, pixel-art friendly (flat, high
/// contrast). Inspired by the Claude Code orange.
class AppColors {
  const AppColors._();

  // Brand orange
  static const Color bunOrange = Color(0xFFE8732C);
  static const Color orangeDark = Color(0xFFB5531A);
  static const Color orangeLight = Color(0xFFFFD9B8);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color paper = Color(0xFFFAF7F2); // app background
  static const Color ink = Color(0xFF1E1B17); // primary text / pixel borders

  static const Color gray100 = Color(0xFFF1ECE6);
  static const Color gray200 = Color(0xFFE3DBD1);
  static const Color gray300 = Color(0xFFCBC1B5);
  static const Color gray400 = Color(0xFFA89E91);
  static const Color gray500 = Color(0xFF867C70);
  static const Color gray600 = Color(0xFF655D53);
  static const Color gray700 = Color(0xFF463F38);

  // Semantic (transaction directions)
  static const Color income = Color(0xFF2E9E5B);
  static const Color expense = Color(0xFFD64545);
  static const Color transfer = Color(0xFF3D7DCA);

  static Color forHex(String hex) {
    final value = hex.replaceAll('#', '');
    final withAlpha = value.length == 6 ? 'FF$value' : value;
    return Color(int.parse(withAlpha, radix: 16));
  }
}
