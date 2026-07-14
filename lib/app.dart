import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/utils/money.dart';
import 'l10n/generated/app_localizations.dart';

/// The GoRouter, created once for the app's lifetime.
final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref));

class MoneyBunApp extends ConsumerWidget {
  const MoneyBunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final settings = ref.watch(appSettingsProvider).value;
    // Keep the automatic-sync controller alive for the app's lifetime (it
    // syncs on sign-in, launch, resume, and after edits). Null until Firebase
    // is configured + the user is signed in.
    ref.watch(syncControllerProvider);
    // Re-assert the daily reminder schedule once per launch.
    ref.watch(reminderBootstrapProvider);
    // Keep the membership chain (membership → settings/slips) actively
    // listened for the app's lifetime WHILE SIGNED IN. Without a permanent
    // listener Riverpod 3 leaves the chain inactive: invalidations pile up
    // unflushed and are then replayed synchronously inside the first screen
    // that watches planProvider (Settings), which throws "setState() called
    // during build" on the root scope every time that screen opens. Gated on
    // sign-in (rather than watched unconditionally) so a signed-out session
    // isn't paying for membershipProvider's live Drift query + its 15-minute
    // re-derive timer for the entire process lifetime with nothing to track.
    if (ref.watch(authStateProvider).value != null) {
      ref.watch(membershipProvider);
    }

    final themeMode = switch (settings?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // Drive the money formatter from the user's currency setting so every
    // amount reformats when it changes (this widget rebuilds on settings change).
    Money.setCurrency(settings?.currencyCode ?? 'THB');

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: AppColors.terra),
      darkTheme: AppTheme.dark(accent: AppColors.terra),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      // Keep the status / navigation bars in step with the active theme so
      // their icons stay legible when the user switches to dark mode.
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
