import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A rounded-square tinted icon tile (terra-wash bg + terra-700 icon by
/// default). Used throughout the design for category/row/account icons.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.size = 42,
    this.radius = 14,
    this.iconSize = 20,
    this.background = AppColors.terraWash,
    this.foreground = AppColors.terra700,
    this.circle = false,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;
  final Color background;
  final Color foreground;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
