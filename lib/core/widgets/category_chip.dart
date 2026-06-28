import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import 'app_icons.dart';
import 'category_emoji.dart';
import 'emoji_chip.dart';
import 'icon_chip.dart';

/// A category's leading chip: its emoji on a soft wash of its colour.
///
/// Pass a category's [iconKey] + [colorHex] (use `category?.iconKey` /
/// `category?.colorHex` so a null category falls through). When either is null
/// — e.g. the stats "อื่นๆ" bucket or an "all categories" budget — it shows
/// [fallbackIcon] in a neutral terra chip instead, matching the pre-emoji look.
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
    return EmojiChip(
      emoji: CategoryEmoji.forKey(iconKey),
      size: size,
      radius: radius,
      emojiSize: glyphSize,
      circle: circle,
      background: AppColors.softHex(colorHex!),
    );
  }
}
