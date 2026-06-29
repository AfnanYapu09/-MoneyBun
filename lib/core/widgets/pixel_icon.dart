import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import 'category_icons.dart';
import 'icon_chip.dart';
import 'pixel_icons_data.dart';

// Re-export the generated data (glyph map + catalogue) so callers only need to
// import this file.
export 'pixel_icons_data.dart' show kPixelGlyphs, kPixelIconCatalog;

/// One 16×16 pixel-art glyph: an ARGB [palette] (index 0 is transparent) and a
/// 16-row grid of palette indices. Generated from the "Bun Pixel Icons" design
/// handoff — see `pixel_icons_data.dart` and `tool/gen_pixel_icons.js`.
class PixelGlyph {
  const PixelGlyph({required this.palette, required this.pixels});
  final List<Color> palette;
  final List<List<int>> pixels;
}

/// Catalogue entry for a pixel icon: drives the icon picker and the category
/// seed. [colorHex] is an ARGB hex string (e.g. `FFC77E5E`) matching the app's
/// `colorHex` convention.
class PixelIconInfo {
  const PixelIconInfo({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.colorHex,
    required this.income,
  });
  final String id;
  final String nameTh;
  final String nameEn;
  final String colorHex;
  final bool income;
}

/// Whether [key] resolves to a pixel-art glyph (vs. a legacy font-icon key).
bool hasPixelGlyph(String? key) => key != null && kPixelGlyphs.containsKey(key);

/// Paints a [PixelGlyph] crisply: anti-aliasing off, with a half-pixel overscan
/// so adjacent cells never leave a seam. The 16×16 grid fills the given size.
class PixelIconPainter extends CustomPainter {
  const PixelIconPainter(this.glyph);
  final PixelGlyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = glyph.pixels;
    final n = pixels.length;
    if (n == 0) return;
    final cell = size.width / n;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < n; y++) {
      final row = pixels[y];
      for (var x = 0; x < row.length; x++) {
        final idx = row[x];
        if (idx == 0) continue; // transparent
        paint.color = glyph.palette[idx];
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelIconPainter old) => old.glyph != glyph;
}

/// Renders the pixel-art glyph for [iconKey] at [size]×[size]. Falls back to an
/// empty box when the key has no glyph — prefer [CategoryGlyph], which renders a
/// tile and falls back to a font icon.
class PixelIcon extends StatelessWidget {
  const PixelIcon(this.iconKey, {super.key, this.size = 24});
  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = iconKey == null ? null : kPixelGlyphs[iconKey];
    if (glyph == null) return SizedBox(width: size, height: size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: PixelIconPainter(glyph)),
    );
  }
}

/// A category's leading icon tile, used everywhere a category icon appears.
///
/// When [iconKey] has a pixel-art glyph it draws the full-colour pixel art on a
/// cream [AppColors.pixelTile] tile (matching the design). Otherwise it falls
/// back to the legacy tinted font-icon [IconChip] so older category keys still
/// render. [color] is the category colour (the tile fill for the fallback).
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    super.key,
    required this.iconKey,
    required this.color,
    this.size = 42,
    this.radius = 14,
    this.iconSize = 20,
    this.circle = false,
  });

  final String? iconKey;
  final Color color;
  final double size;
  final double radius;

  /// Font-icon size used only for the legacy fallback.
  final double iconSize;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (!hasPixelGlyph(iconKey)) {
      return IconChip(
        icon: CategoryIcons.forKey(iconKey),
        size: size,
        radius: radius,
        iconSize: iconSize,
        circle: circle,
        background: color,
        foreground: AppColors.reverse,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.pixelTile,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      // A square glyph in a circle needs more inset so its corners stay inside.
      child: PixelIcon(iconKey, size: size * (circle ? 0.66 : 0.74)),
    );
  }
}
