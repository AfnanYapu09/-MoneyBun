import 'package:flutter/material.dart';

import '../theme/typography.dart';

/// Picks the pixel display font only when the text is purely Latin/numeric
/// (which the pixel font can render); otherwise falls back to Noto Sans Thai so
/// Thai content always renders correctly.
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.size = 12,
    this.color,
    this.forcePixel = false,
    this.textAlign,
    this.letterSpacing = 0,
  });

  final String text;
  final double size;
  final Color? color;

  /// Force the pixel font even if content might not be Latin-only.
  final bool forcePixel;
  final TextAlign? textAlign;
  final double letterSpacing;

  static final RegExp _latinNumeric = RegExp(r'^[\x20-\x7E]*$');

  bool get _canPixel => forcePixel || _latinNumeric.hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color;
    final style = _canPixel
        ? AppTypography.pixel(
            size: size, color: c!, letterSpacing: letterSpacing)
        : AppTypography.body(
            size: size * 1.25, weight: FontWeight.w800, color: c!);
    return Text(text, style: style, textAlign: textAlign);
  }
}
