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

  Future<void> refresh(String uid) async {
    // Seed the signup cache from auth metadata (server-set creation time) —
    // cheap, and keeps the fallback warm for offline launches.
    try {
      final creation = _auth.currentUser?.metadata.creationTime;
      if (creation != null && (await _settings.read()).signupAtMs == null) {
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
      await _settings.setCreditsGranted(granted);
      await _settings.setHasRedeemed(redeemed);
      await _settings.setHasReferred(referred || referrals > 0);
    } catch (_) {
      // Best-effort cache refresh: offline or a transient failure keeps the
      // previous cache rather than zeroing a real balance.
    }
  }
}
