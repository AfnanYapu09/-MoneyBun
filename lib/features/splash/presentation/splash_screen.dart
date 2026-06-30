import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/wordmark.dart';
import '../../../l10n/generated/app_localizations.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final settings = await ref.read(settingsRepositoryProvider).read();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    context.go(settings.onboardingSeen ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.terra,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(38),
                  ),
                  alignment: Alignment.center,
                  child: const BunAvatar(size: 112),
                ),
                const SizedBox(height: 26),
                const Wordmark(size: 44, color: AppColors.reverse),
                const SizedBox(height: 10),
                Text(l10n.splashTagline,
                    style: TextStyle(
                      color: AppColors.reverse.withValues(alpha: 0.82),
                      fontSize: 15,
                    )),
              ],
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        AppColors.reverse.withValues(alpha: i == 0 ? 1 : 0.4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
