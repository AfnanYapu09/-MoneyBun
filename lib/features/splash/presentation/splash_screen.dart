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
    final auth = ref.read(authServiceProvider);
    // Resolve the restored auth state concurrently with the brand beat.
    // currentUser can still be null right after launch until Firebase finishes
    // reading its persisted session, so fall back to the first authStateChanges
    // emission (bounded) — otherwise a returning user would flash the login
    // screen before the router redirect bounces them back to Home.
    final Future<bool> signedInFuture = auth == null
        ? Future.value(false)
        : auth.currentUser != null
            ? Future.value(true)
            : auth
                .authStateChanges()
                .first
                .timeout(const Duration(seconds: 2), onTimeout: () => null)
                .then((u) => u != null);
    // A short brand beat — kept snappy so the app reaches Home (and the local
    // data already waiting there) without a needless wait on every cold start.
    await Future.delayed(const Duration(milliseconds: 600));
    final signedIn = await signedInFuture;
    if (!mounted) return;
    if (!settings.onboardingSeen) {
      context.go('/onboarding');
      return;
    }
    // Cloud-only: the app requires a signed-in account. The router's redirect
    // enforces this for every route as a safety net.
    context.go(signedIn ? '/home' : '/login');
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
                Text(
                  l10n.splashTagline,
                  style: TextStyle(
                    color: AppColors.reverse.withValues(alpha: 0.82),
                    fontSize: 15,
                  ),
                ),
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
                    color: AppColors.reverse.withValues(
                      alpha: i == 0 ? 1 : 0.4,
                    ),
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
