import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Shown in place of a screen's body when the feature needs Pro or above
/// (export, recurring entries). Free users see the lock and a path to the
/// plans screen instead of the feature.
class ProFeatureGate extends StatelessWidget {
  const ProFeatureGate({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: context.palette.terraWash,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.sparkles,
                size: 34,
                color: context.palette.terraFg,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.featureNeedsPro,
              textAlign: TextAlign.center,
              style: AppTypography.heading(size: 16, weight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.planHowTo,
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, color: context.palette.ink2),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: l10n.viewPlans,
                onPressed: () => context.push('/settings/plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
