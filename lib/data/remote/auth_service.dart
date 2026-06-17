import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth + Google Sign-In (v7 API: `initialize()` then
/// `authenticate()`). Requires the user's real Firebase config + a
/// `serverClientId` (the web OAuth client id) to actually work on a device.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  bool _gsiInitialized = false;

  /// The Web OAuth client id from the Firebase/Google Cloud console. Pass it at
  /// build time so the ID token's audience is accepted by Firebase Auth on
  /// Android:
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  Future<void> _ensureGsi() async {
    if (_gsiInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _gsiInitialized = true;
  }

  Future<User?> signInWithGoogle() async {
    await _ensureGsi();
    final gsi = GoogleSignIn.instance;
    if (!gsi.supportsAuthenticate()) {
      throw UnsupportedError(
          'Google Sign-In is not supported on this platform');
    }
    final account = await gsi.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In returned no ID token');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore: sign-out of GSI is best-effort.
    }
    await _auth.signOut();
  }
}
