import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bootstrap/firebase_options.dart';
import 'bootstrap/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
