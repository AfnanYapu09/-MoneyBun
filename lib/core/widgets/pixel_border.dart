import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/pixel_theme.dart';

/// A container with the signature pixel look: a chunky ink border and a hard
/// (non-blurred) offset drop shadow.
class PixelBorder extends StatelessWidget {
  const PixelBorder({
    super.key,
    required this.child,
    this.color = AppColors.white,
    this.borderColor = AppColors.ink,
    this.shadow = true,
    this.padding = const EdgeInsets.all(PixelTokens.unit * 1.5),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final bool shadow;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: PixelTokens.borderRadius,
        border: PixelTokens.inkBorder(color: borderColor),
        boxShadow: shadow ? PixelTokens.hardShadow() : null,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, child: box);
  }
}
