import '../../../data/remote/auth_service.dart';
import '../../../data/repositories/settings_repository.dart';
import '../domain/quota_period.dart';
import 'referral_service.dart';

/// Refreshes the local membership caches from Firestore — called after every
/// completed sync and right after a successful redeem. Everything it writes
/// is a local, re-derivable cache: the truth lives in the redemption/marker
/// docs (grants) and the local slips table (usage).
class CreditsService {
  CreditsService(this._referral, this._settings, this._auth);

  final ReferralService _referral;
  final SettingsRepository _settings;
  final AuthService _auth;

  /// In-flight refresh, if any. This runs unawaited after every completed
  /// sync AND right after a redeem — those two commonly overlap (e.g. a
  /// background post-sync refresh still mid-flight when the user redeems).
  /// Each call's reads+write is a full re-derive from Firestore, not an
  /// increment, so without serializing them a STALE read (started before a
  /// redemption committed) can finish its write AFTER a fresher one and
  /// silently revert the local credit balance back down. Queuing behind the
  /// in-flight call means whichever refresh is issued last also reads (and
  /// therefore writes) last — its view is never overwritten by an older one.
  Future<bool>? _inFlight;

  Future<bool> refresh(String uid, {bool Function()? stillValid}) {
    final existing = _inFlight;
    if (existing != null) {
      return existing.then((_) => refresh(uid, stillValid: stillValid));
    }
    final future = _refresh(uid, stillValid: stillValid);
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  /// Returns whether the cache was actually rewritten (false on a failed
  /// derive or a stale session), so callers that NEED the result — the redeem
  /// success path — can fall back instead of assuming it landed.
  ///
  /// [stillValid] is re-checked before every settings write: refresh runs
  /// unawaited after a sync, so a sign-out wipe can complete while the
  /// Firestore reads above are still in flight — writing then would plant the
  /// OLD account's balance/markers into the next account's settings.
  Future<bool> _refresh(String uid, {bool Function()? stillValid}) async {
    bool live() => stillValid == null || stillValid();

    // Seed the signup cache from auth metadata (server-set creation time) —
    // cheap, and keeps the fallback warm for offline launches.
    try {
      final creation = _auth.currentUser?.metadata.creationTime;
      if (creation != null && (await _settings.read()).signupAtMs == null) {
        if (!live()) return false;
        await _settings.setSignupAtMs(creation.millisecondsSinceEpoch);
      }
    } catch (_) {}

    try {
      final redeemed = await _referral.hasRedeemed(uid);
      final referred = await _referral.hasReferred(uid);
      // Walk every candidate code, not just attempt 0: publishMyCode can have
      // landed on a later attempt (hash collision with another user's code).
      var referrals = 0;
      for (var attempt = 0; attempt < 4; attempt++) {
        referrals += await _referral.countNewRedemptions(
            ReferralService.codeForUid(uid, attempt: attempt));
      }
      final granted = QuotaPeriod.referralCredit * referrals +
          (redeemed ? QuotaPeriod.referralCredit : 0);
      if (!live()) return false;
      await _settings.setCreditsGranted(granted);
      await _settings.setHasRedeemed(redeemed);
      await _settings.setHasReferred(referred || referrals > 0);
      return true;
    } catch (_) {
      // Best-effort cache refresh: offline or a transient failure keeps the
      // previous cache rather than zeroing a real balance.
      return false;
    }
  }
}
