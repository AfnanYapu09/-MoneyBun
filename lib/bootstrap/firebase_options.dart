// Firebase configuration for MoneyBun.
//
// Generated from the project's google-services.json (Android app). These are
// client config values that ship inside every build — they are not secrets;
// data access is protected by the Firestore security rules (firestore.rules).
//
// To reconfigure or add more platforms (iOS/web), run `flutterfire configure`.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  /// Real config is in place. (main() also enables Firebase only when the
  /// apiKey does not start with PLACEHOLDER, which is what turns on login and
  /// cloud sync.)
  static const bool isPlaceholder = false;

  /// MoneyBun ships for Android, so the Android project config is used on every
  /// platform. On a non-Android target `Firebase.initializeApp` may not
  /// complete; main() catches that and falls back to fully-local mode.
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCT7_Eaf5v2IpBtJlw3vev9r8VI-zBvG5U',
    appId: '1:881474200616:android:690a00b3c94cd4592d811d',
    messagingSenderId: '881474200616',
    projectId: 'studio-3816117841-f3521',
    storageBucket: 'studio-3816117841-f3521.firebasestorage.app',
  );
}
