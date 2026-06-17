import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Mood states for the Bun mascot.
enum BunMood { idle, happy, sleepy }

/// "Bun" — the orange pixel mascot, drawn with a [CustomPainter] on a fixed
/// pixel grid so it stays crisp at any size (FilterQuality is irrelevant — it's
/// vector-drawn squares). Swap to real PNG art later via [BunAvatar.asset].
class BunAvatar extends StatelessWidget {
  const BunAvatar({super.key, this.size = 64, this.mood = BunMood.idle});

  final double size;
  final BunMood mood;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BunPainter(mood)),
    );
  }
}

class _BunPainter extends CustomPainter {
  _BunPainter(this.mood);

  final BunMood mood;

  // 16x16 pixel grid. Each cell is one of:
  // '.' transparent, 'O' orange, 'D' dark orange, 'W' white (belly/face),
  // 'K' ink (outline/eyes), 'P' pink (cheeks/inner ear).
  static const List<String> _grid = [
    '..K........K....',
    '.KOK......KOK...',
    '.KODK....KDOK...',
    '.KOPK....KPOK...',
    '.KOOK....KOOK...',
    '..KOK....KOK....',
    '..KOOKKKKKOOK...',
    '.KOOOOOOOOOOOK..',
    '.KOWWOOOOWWOK...',
    '.KOWKWOOWKWOK...',
    '.KOOOOOOOOOOOK..',
    '.KOOPOOOOPOOOK..',
    '.KOWWWWWWWWWOK..',
    '.KOWWWWWWWWWOK..',
    '..KOOOOOOOOOK...',
    '...KKKKKKKKK....',
  ];

  Color? _color(String c) {
    switch (c) {
      case 'O':
        return AppColors.bunOrange;
      case 'D':
        return AppColors.orangeDark;
      case 'W':
        return AppColors.white;
      case 'K':
        return AppColors.ink;
      case 'P':
        return const Color(0xFFF2A6A0);
      default:
        return null;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 16;
    final paint = Paint()..isAntiAlias = false;

    for (var y = 0; y < _grid.length; y++) {
      final row = _grid[y];
      for (var x = 0; x < row.length; x++) {
        var ch = row[x];

        // Mood tweaks on the eye rows (rows 8-9, eye columns).
        if (mood == BunMood.sleepy && y == 9 && (ch == 'K')) ch = 'O';
        if (mood == BunMood.sleepy && y == 8 && (x == 4 || x == 9)) ch = 'K';

        final color = _color(ch);
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }

    // Happy: tiny sparkle to the side.
    if (mood == BunMood.happy) {
      paint.color = AppColors.orangeDark;
      canvas.drawRect(Rect.fromLTWH(14 * cell, 2 * cell, cell, cell), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BunPainter old) => old.mood != mood;
}
