import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'bootstrap/firebase_options.dart';
import 'bootstrap/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers: keep an uncaught async error (a failed plugin call,
  // a stray Firestore exception) from killing the whole app, and make errors
  // visible in logs — without these, release-mode failures vanish silently.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}\n'
        '${details.stack ?? ''}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true; // handled — don't crash the app
  };
  // (initializeDateFormatting runs concurrently in the Future.wait below.)

  // Use the bundled fonts in google_fonts/ instead of fetching at runtime
  // (works fully offline).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Cloud-only: the app requires a signed-in Firebase account (a local Drift
  // cache still backs it for speed + offline reads). Firebase is initialised
  // only when real config is present (after `flutterfire configure` replaces the
  // placeholder); detection inspects the apiKey so it survives a regenerated
  // firebase_options.dart with no `isPlaceholder` flag. A build without real
  // config can't sign in, so it can't be used until configured.
  Future<bool> initFirebase() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.startsWith('PLACEHOLDER')) return false;
    try {
      await Firebase.initializeApp(options: options);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Run the two startup awaits CONCURRENTLY (intl locale data + Firebase) so
  // the first frame — the splash's Bun jump — appears as early as possible.
  final results = await Future.wait([
    // Load locale data for `intl`'s DateFormat so Thai (`th_TH`) and English
    // (`en_US`) date/month/weekday names render in either language. Without
    // this, formatting a date in a non-default locale throws once the user
    // switches.
    initializeDateFormatting().then((_) => true),
    initFirebase(),
  ]);
  final firebaseReady = results[1];

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const MoneyBunApp(),
    ),
  );
}
