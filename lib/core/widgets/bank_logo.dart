import 'package:flutter/material.dart';

import '../constants/bank_catalog.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// A bank's logo: the bundled image `assets/banks/<id>.png` when present,
/// otherwise a brand-coloured circular badge with the bank's short name. Logos
/// are third-party trademarks shown only to identify the bank (nominative use).
class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.bank, this.size = 42});

  final ScanBank bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/banks/${bank.id}.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _badge(),
      ),
    );
  }

  Widget _badge() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.forHex(bank.brandHex),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: FittedBox(
          child: Text(
            bank.shortName,
            style: AppTypography.heading(
              size: 14,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
