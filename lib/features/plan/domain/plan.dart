import 'dev_accounts.dart';

/// Membership tiers:
/// - **Free** — core tracking, 30 slip scans/month; export and recurring
///   entries are locked.
/// - **Pro** — every feature, 300 scans/month. Unlocked by referral: a friend
///   enters your code (or you enter theirs) and BOTH accounts get Pro for the
///   current calendar month (`proMonth` synced setting; the reset is automatic
///   because the stored month is compared to today).
/// - **Ultra** — no limits at all. Paid; granted by setting the synced
///   `ultraUntil` setting to a 'YYYY-MM-DD' expiry (today the developer sets
///   it manually in the Firebase console after payment — no in-app billing).
enum PlanTier { free, pro, ultra }

class Plan {
  const Plan._(this.tier);

  final PlanTier tier;

  static const free = Plan._(PlanTier.free);
  static const pro = Plan._(PlanTier.pro);
  static const ultra = Plan._(PlanTier.ultra);

  static const freeScanLimit = 30;
  static const proScanLimit = 300;

  bool get isFree => tier == PlanTier.free;
  bool get isPro => tier == PlanTier.pro;
  bool get isUltra => tier == PlanTier.ultra;

  /// Monthly slip-scan cap, or null = unlimited (Ultra).
  int? get scanLimit => switch (tier) {
        PlanTier.free => freeScanLimit,
        PlanTier.pro => proScanLimit,
        PlanTier.ultra => null,
      };

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

  /// Resolve the plan from [uid] and the synced settings. A developer
  /// account ([DevAccounts]) is always Ultra, no matter what's stored.
  /// Otherwise: Ultra (paid, until its expiry date inclusive) outranks Pro
  /// (referral, this month only).
  static Plan resolve({
    required String uid,
    required String proMonth,
    required String ultraUntil,
    required DateTime now,
  }) {
    if (DevAccounts.isDev(uid)) return ultra;
    if (ultraUntil.isNotEmpty && dayKey(now).compareTo(ultraUntil) <= 0) {
      return ultra;
    }
    if (proMonth == monthKey(now)) return pro;
    return free;
  }
}
