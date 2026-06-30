import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// The `moneyBun` wordmark in Fraunces. `money` is lighter, `Bun` is bolder.
///
/// [color] defaults to the theme's primary ink so the logo stays legible in
/// both light and dark mode; pass an explicit colour on tinted backgrounds.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 30, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.ink;
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'money',
            style: AppTypography.display(
                    size: size, weight: FontWeight.w500, color: c)
                .copyWith(color: c.withValues(alpha: 0.78)),
          ),
          TextSpan(
            text: 'Bun',
            style: AppTypography.display(
                size: size, weight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}
