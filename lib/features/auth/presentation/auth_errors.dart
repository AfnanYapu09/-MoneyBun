import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Whether [error] means the user dismissed the Google/Apple sign-in sheet
/// themselves — not a failure, so no error snack should be shown.
bool isAuthCancelled(Object error) {
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled ||
        error.code == GoogleSignInExceptionCode.interrupted;
  }
  if (error is SignInWithAppleAuthorizationException) {
    return error.code == AuthorizationErrorCode.canceled;
  }
  return false;
}

/// Maps a Firebase Auth error to a clear, localized message so the user knows
/// exactly why a sign-up / sign-in / reset failed. Falls back to [fallback]
/// (the screen's generic message) for anything unrecognised.
String authErrorMessage(
  Object error,
  AppLocalizations l10n, {
  required String fallback,
}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return l10n.authErrEmailInUse;
      case 'invalid-email':
        return l10n.authErrInvalidEmail;
      case 'weak-password':
        return l10n.authErrWeakPassword;
      // Modern Firebase returns invalid-credential for both a wrong password
      // and an unknown account (email-enumeration protection).
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return l10n.authErrWrongCredentials;
      case 'user-disabled':
        return l10n.authErrUserDisabled;
      case 'too-many-requests':
        return l10n.authErrTooManyRequests;
      case 'network-request-failed':
        return l10n.authErrNetwork;
      case 'operation-not-allowed':
        return l10n.authErrOperationNotAllowed;
      case 'account-exists-with-different-credential':
        return l10n.authErrAccountExists;
      case 'provider-already-linked':
        return l10n.authErrAlreadyLinked;
      case 'credential-already-in-use':
        return l10n.authErrCredentialInUse;
    }
  }
  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return l10n.authErrGoogleConfig;
      default:
        return l10n.authErrGoogleFailed;
    }
  }
  return fallback;
}
