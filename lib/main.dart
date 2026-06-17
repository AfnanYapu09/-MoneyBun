import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'bootstrap/firebase_options.dart';
import 'bootstrap/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use the bundled fonts in google_fonts/ instead of fetching at runtime
  // (works fully offline).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Local-first: the app is fully usable offline. Firebase is initialised only
  // when real config is present (i.e. after `flutterfire configure` replaces the
  // placeholder). Detection works by inspecting the apiKey, so it survives the
  // regenerated firebase_options.dart that has no `isPlaceholder` flag.
  var firebaseReady = false;
  final options = DefaultFirebaseOptions.currentPlatform;
  if (!options.apiKey.startsWith('PLACEHOLDER')) {
    try {
      await Firebase.initializeApp(options: options);
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }
  }

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const MoneyBunApp(),
    ),
  );
}
