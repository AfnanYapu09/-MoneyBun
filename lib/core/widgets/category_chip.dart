import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import 'app_icons.dart';
import 'category_pixel.dart';
import 'icon_chip.dart';
import 'pixel_icon.dart';

/// A category's leading chip: its pixel-art sprite on a soft wash of its colour.
///
/// Pass a category's [iconKey] + [colorHex] (use `category?.iconKey` /
/// `category?.colorHex` so a null category falls through). When either is null
/// — e.g. the stats "อื่นๆ" bucket or an "all categories" budget — it shows
/// [fallbackIcon] in a neutral terra chip instead.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.iconKey,
    required this.colorHex,
    this.size = 42,
    this.radius = 14,
    this.glyphSize = 22,
    this.circle = false,
    this.fallbackIcon = AppIcons.ellipsis,
  });

  final String? iconKey;
  final String? colorHex;
  final double size;
  final double radius;

  /// Icon size for the [fallbackIcon] (no category). The pixel sprite scales
  /// to the chip [size] so it always sits proportionally inside the tile.
  final double glyphSize;
  final bool circle;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (iconKey == null || colorHex == null) {
      return IconChip(
        icon: fallbackIcon,
        size: size,
        radius: radius,
        iconSize: glyphSize,
        circle: circle,
      );
    }
    return PixelIconChip(
      grid: CategoryPixel.forKey(iconKey),
      color: AppColors.forHex(colorHex!),
      size: size,
      radius: radius,
      pixelSize: size * 0.66,
      circle: circle,
      background: AppColors.softHex(colorHex!),
    );
  }
}
