import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// The `moneyBun` wordmark in Fraunces. `money` is lighter, `Bun` is bolder.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 30, this.color = AppColors.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'money',
            style: AppTypography.display(
                    size: size, weight: FontWeight.w500, color: color)
                .copyWith(color: color.withValues(alpha: 0.78)),
          ),
          TextSpan(
            text: 'Bun',
            style: AppTypography.display(
                size: size, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
