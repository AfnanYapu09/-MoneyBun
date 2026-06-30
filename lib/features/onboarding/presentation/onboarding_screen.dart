import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/generated/app_localizations.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _seen(WidgetRef ref) =>
      ref.read(settingsRepositoryProvider).setOnboardingSeen(true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await _seen(ref);
                    if (!context.mounted) return;
                    context.go(
                      ref.read(firebaseReadyProvider) ? '/login' : '/home',
                    );
                  },
                  child: Text(
                    l10n.onbSkip,
                    style: AppTypography.body(
                      size: 14,
                      color: context.palette.ink3,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 256,
                height: 230,
                decoration: BoxDecoration(
                  color: context.palette.terraWash,
                  borderRadius: BorderRadius.circular(44),
                ),
                alignment: Alignment.center,
                child: const BunCalculator(width: 212),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.onbSlideTitle,
                textAlign: TextAlign.center,
                style: AppTypography.heading(size: 25, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.onbSlideBody,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  size: 15,
                  color: context.palette.ink2,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: l10n.onbGetStarted,
                onPressed: () async {
                  await _seen(ref);
                  if (!context.mounted) return;
                  // Cloud-only: new users create an account. Guest (local)
                  // remains only when Firebase isn't configured.
                  if (ref.read(firebaseReadyProvider)) {
                    context.go('/signup');
                  } else {
                    await ref
                        .read(settingsRepositoryProvider)
                        .setAuthMode('guest');
                    if (context.mounted) context.go('/home');
                  }
                },
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: l10n.onbHaveAccount,
                onPressed: () async {
                  await _seen(ref);
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
