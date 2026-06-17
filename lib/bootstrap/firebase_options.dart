// PLACEHOLDER Firebase configuration.
//
// These are NOT real credentials. Replace this whole file by running:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// until then, [DefaultFirebaseOptions.isPlaceholder] stays true and the app
// skips Firebase initialization (it runs fully offline via the local Drift DB).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// True while the placeholder values below are still in place.
  static const bool isPlaceholder = true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _placeholder;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _placeholder;
      case TargetPlatform.iOS:
        return _placeholder;
      default:
        return _placeholder;
    }
  }

  static const FirebaseOptions _placeholder = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'moneybun-placeholder',
    storageBucket: 'moneybun-placeholder.appspot.com',
  );
}
