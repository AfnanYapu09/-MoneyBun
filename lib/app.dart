import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/pixel_theme.dart';
import 'l10n/generated/app_localizations.dart';

/// The GoRouter, created once for the app's lifetime.
final routerProvider = Provider<GoRouter>((ref) => buildRouter());

class MoneyBunApp extends ConsumerWidget {
  const MoneyBunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: PixelTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
