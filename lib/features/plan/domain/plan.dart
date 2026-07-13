import 'dev_accounts.dart';
import 'quota_period.dart';

/// Membership tiers:
/// - **Free** — core tracking, 30 slip scans per personal month (anchored to
///   the signup day, see [QuotaPeriod]); export and recurring entries locked.
/// - **Pro** — every feature, active while the account holds referral credits.
///   Credits are permanent (+300 per referral event, never expire) and are
///   consumed only after the period's free allowance runs out.
/// - **Ultra** — no limits at all. Paid; granted by setting the synced
///   `ultraUntil` setting to a 'YYYY-MM-DD' expiry (the developer sets it
///   manually in the Firebase console after payment — no in-app billing).
enum PlanTier { free, pro, ultra }

class Plan {
  const Plan._(this.tier);

  final PlanTier tier;

  static const free = Plan._(PlanTier.free);
  static const pro = Plan._(PlanTier.pro);
  static const ultra = Plan._(PlanTier.ultra);

  static const freeScanLimit = QuotaPeriod.freePerPeriod;

  bool get isFree => tier == PlanTier.free;
  bool get isPro => tier == PlanTier.pro;
  bool get isUltra => tier == PlanTier.ultra;

  /// Free locks the "power" features; Pro and Ultra have everything.
  bool get canExport => tier != PlanTier.free;
  bool get canUseRecurring => tier != PlanTier.free;

  /// The current calendar month as the canonical 'YYYY-MM' key.
  static String monthKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';

  /// Today as the canonical 'YYYY-MM-DD' key (for ultraUntil comparisons —
  /// string compare works because the fields are zero-padded).
  static String dayKey(DateTime now) =>
      '${monthKey(now)}-${now.day.toString().padLeft(2, '0')}';

  /// Resolve the plan from [uid], the synced `ultraUntil`, and the derived
  /// credit balance. A developer account ([DevAccounts]) is always Ultra.
  /// Otherwise: Ultra (paid, until its expiry date inclusive) outranks Pro
  /// (any positive credit balance).
  static Plan resolve({
    required String uid,
    required String ultraUntil,
    required int creditBalance,
    required DateTime now,
  }) {
    if (DevAccounts.isDev(uid)) return ultra;
    if (ultraUntil.isNotEmpty && dayKey(now).compareTo(ultraUntil) <= 0) {
      return ultra;
    }
    if (creditBalance > 0) return pro;
    return free;
  }
}

/// The full membership snapshot the UI and the slip importer consume: the
/// resolved [plan] plus the quota numbers it was resolved from.
class Membership {
  const Membership({
    required this.plan,
    required this.freeUsed,
    required this.creditsGranted,
    required this.creditsUsed,
    required this.periodStart,
    required this.periodResetAt,
    required this.isOld,
    required this.backfillCutoffMs,
  });

  /// Guest / not-yet-loaded fallback: plain Free with a calendar-month period.
  factory Membership.fallback(DateTime now) {
    final start = DateTime(now.year, now.month);
    return Membership(
      plan: Plan.free,
      freeUsed: 0,
      creditsGranted: 0,
      creditsUsed: 0,
      periodStart: start,
      periodResetAt: DateTime(now.year, now.month + 1),
      isOld: false,
      backfillCutoffMs: 0,
    );
  }

  final Plan plan;

  /// Countable slips imported in the current personal period.
  final int freeUsed;

  /// Permanent credits earned from referrals (derived from Firestore, cached).
  final int creditsGranted;

  /// Credits consumed across all periods (derived from local slips).
  final int creditsUsed;

  /// Bounds of the current personal free period.
  final DateTime periodStart;
  final DateTime periodResetAt;

  /// Referral status: this account has redeemed a code OR had its own code
  /// redeemed. Old accounts can keep inviting but can never redeem again.
  final bool isOld;

  /// Photos taken before this (epoch ms) import free — the signup-month
  /// backfill. 0 = unknown signup (guest) → no backfill.
  final int backfillCutoffMs;

  bool get unlimited => plan.isUltra;

  int get freeRemaining {
    final left = QuotaPeriod.freePerPeriod - freeUsed;
    return left > 0 ? left : 0;
  }

  int get creditBalance {
    final b = creditsGranted - creditsUsed;
    return b > 0 ? b : 0;
  }

  /// How many more slips can be scanned right now (free first, then credits).
  int get remainingScans => unlimited ? 1 << 30 : freeRemaining + creditBalance;
}
