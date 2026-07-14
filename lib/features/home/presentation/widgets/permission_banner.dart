import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../bootstrap/providers.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Persistent Home banner shown while photo access is denied (or limited on
/// Android 14). Stays until the permission is actually granted — the app's
/// core slip auto-scan cannot work without it — then dismisses itself and
/// kicks off a scan.
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  Future<void> _fix(WidgetRef ref, PhotoPermStatus status) async {
    // Everything is captured BEFORE the awaits: the user leaves the app for
    // the OS prompt/settings, and this element can be unmounted by the time
    // they return — ref.read would then throw and the re-check be skipped.
    final importer = ref.read(slipImporterProvider);
    final permission = ref.read(photoPermissionProvider.notifier);
    final scan = ref.read(scanControllerProvider.notifier);
    if (status == PhotoPermStatus.limited) {
      // Widen the Android 14 partial selection.
      await importer.presentLimited();
    } else {
      // Re-request first: on a fresh deny the OS prompt can still appear.
      // After "don't ask again" it returns denied instantly — go to settings.
      final perm = await importer.requestPermission();
      if (!perm.granted) await importer.openSettings();
    }
    if (await permission.refresh() == PhotoPermStatus.granted) {
      await scan.scan();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(photoPermissionProvider);
    if (status == PhotoPermStatus.unknown ||
        status == PhotoPermStatus.granted) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final limited = status == PhotoPermStatus.limited;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.palette.terraWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.palette.bg,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(
              AppIcons.image,
              size: 20,
              color: context.palette.terraFg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homePermBannerTitle,
                  style: AppTypography.heading(
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  limited
                      ? l10n.homePermBannerLimitedBody
                      : l10n.homePermBannerBody,
                  style: AppTypography.body(
                    size: 12.5,
                    color: context.palette.ink2,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: () => _fix(ref, status),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terra,
                foregroundColor: AppColors.reverse,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n.homePermBannerCta,
                style: AppTypography.heading(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.reverse,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
