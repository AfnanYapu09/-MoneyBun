import 'package:firebase_auth/firebase_auth.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Maps a Firebase Auth error to a clear, localized message so the user knows
/// exactly why a sign-up / sign-in / reset failed. Falls back to [fallback]
/// (the screen's generic message) for anything unrecognised.
String authErrorMessage(Object error, AppLocalizations l10n,
    {required String fallback}) {
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
    }
  }
  return fallback;
}
