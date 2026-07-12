import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'sync_blur.dart';

/// Home income/expense chip: small icon + label on top, amount below.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.amount,
    required this.accent,
    this.amountColor,
    this.blurAmount = false,
  });

  final IconData icon;
  final String label;
  final String amount;
  final Color accent;
  final Color? amountColor;

  /// Blur the number while the first cloud pull is still loading it.
  final bool blurAmount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.body(
                  size: 13,
                  color: context.palette.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SyncBlur(
            active: blurAmount,
            child: Text(
              amount,
              style: AppTypography.heading(
                size: 19,
                weight: FontWeight.w500,
                color: amountColor ?? context.palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
