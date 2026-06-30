import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Wraps Firebase Auth + Google / Apple / email-password sign-in. Requires the
/// user's real Firebase config to actually work on a device; the app remains
/// fully usable offline as a guest when [authServiceProvider] is null.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  bool _gsiInitialized = false;

  /// The Web OAuth client id from the Firebase/Google Cloud console (passed via
  ///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com).
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  // ---- Email / password --------------------------------------------------

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    return result.user;
  }

  Future<User?> signUpWithEmail(
      String name, String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    if (name.trim().isNotEmpty) {
      await result.user?.updateDisplayName(name.trim());
    }
    return result.user;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ---- Google ------------------------------------------------------------

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

  // ---- Apple (iOS/macOS only) -------------------------------------------

  bool get supportsApple => Platform.isIOS || Platform.isMacOS;

  Future<User?> signInWithApple() async {
    if (!supportsApple) {
      throw UnsupportedError('Apple Sign-In is only available on iOS/macOS');
    }
    final rawNonce = _nonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
    final result = await _auth.signInWithCredential(oauth);
    return result.user;
  }

  String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)])
        .join();
  }

  // ---- Sign out ----------------------------------------------------------

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // best-effort
    }
    await _auth.signOut();
  }
}
