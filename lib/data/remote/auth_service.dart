import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Wraps Firebase Auth + Google / Apple / email-password sign-in. Requires the
/// user's real Firebase config; the app is cloud-only, so when
/// [authServiceProvider] is null (config not set up) sign-in is unavailable and
/// the app cannot be used until it is configured.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  bool _gsiInitialized = false;

  /// The Web OAuth client id from the Firebase/Google Cloud console. A web
  /// client id is public by design (it ships in every web app's JS), so the
  /// project default is checked in; --dart-define=GOOGLE_SERVER_CLIENT_ID
  /// still overrides it for other Firebase projects.
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '881474200616-7tmiknbktnl3hq8bfj0dlvie4i7ljjkr.apps.googleusercontent.com',
  );

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;

  // ---- Email / password --------------------------------------------------

  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return result.user;
  }

  Future<User?> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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

  /// Runs the Google account-chooser and returns the Firebase credential, or
  /// null when the user backs out. Throws for real failures.
  Future<AuthCredential?> _googleCredential() async {
    await _ensureGsi();
    final gsi = GoogleSignIn.instance;
    if (!gsi.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In is not supported on this platform',
      );
    }
    final GoogleSignInAccount account;
    try {
      account = await gsi.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In returned no ID token');
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  /// Returns null when the user backs out of the account chooser; throws for
  /// real failures (configuration, network, Firebase). [isNew] tells whether
  /// this Google sign-in just created the account — used to show the app tour
  /// to genuinely-new users only.
  Future<({User user, bool isNew})?> signInWithGoogle() async {
    final credential = await _googleCredential();
    if (credential == null) return null;
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return null;
    return (user: user, isNew: result.additionalUserInfo?.isNewUser ?? false);
  }

  /// Whether the signed-in account already has Google linked.
  bool get googleLinked =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  /// Link Google to the currently signed-in account so the user can also sign
  /// in with Google later. Returns false when the chooser was dismissed.
  Future<bool> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final credential = await _googleCredential();
    if (credential == null) return false;
    await user.linkWithCredential(credential);
    await user.reload();
    return true;
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
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      // Documented to happen (rarely) — fail with a clear error instead of
      // handing Firebase a null token.
      throw StateError('Apple Sign-In returned no identity token');
    }
    final oauth = OAuthProvider(
      'apple.com',
    ).credential(idToken: idToken, rawNonce: rawNonce);
    final result = await _auth.signInWithCredential(oauth);
    // Apple supplies the full name ONLY on the very first authorization —
    // discard it here and it is unrecoverable (re-auth never re-delivers it),
    // leaving the account on the default display name forever.
    final user = result.user;
    final given = appleCredential.givenName;
    if (user != null &&
        (user.displayName == null || user.displayName!.isEmpty) &&
        given != null &&
        given.isNotEmpty) {
      final family = appleCredential.familyName;
      final name =
          family == null || family.isEmpty ? given : '$given $family';
      try {
        await user.updateDisplayName(name);
      } catch (_) {
        // Cosmetic — never fail the sign-in over it.
      }
    }
    return result.user;
  }

  String _nonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
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
