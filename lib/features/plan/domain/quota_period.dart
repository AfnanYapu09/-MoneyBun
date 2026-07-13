/// Pure date/quota math for the membership system: personal free periods
/// anchored to the signup day, the free-backfill cutoff, and permanent
/// Pro-credit accounting. No Flutter/Firebase imports — unit-testable.
///
/// The model (owner's spec):
/// - Signup day itself is a grace day: every slip photo taken before local
///   midnight AFTER the signup day imports free (the "backfill" — e.g. signup
///   13/7 → photos from 1–13/7 are free).
/// - Free counting starts the day after signup (the *anchor*) and grants
///   [freePerPeriod] scans per personal month: anchor 14/7 resets 14/8, 14/9…
///   Unused free never carries over.
/// - Referral credits ([referralCredit] per event) are permanent: they never
///   reset or expire, and are consumed only after the period's free allowance.
class QuotaUsage {
  const QuotaUsage({
    required this.freeUsedThisPeriod,
    required this.creditsUsed,
  });

  /// Countable slips imported inside the current personal period.
  final int freeUsedThisPeriod;

  /// Total credits ever consumed: the sum over every period of the overage
  /// beyond the free allowance.
  final int creditsUsed;
}

class QuotaPeriod {
  const QuotaPeriod._();

  /// Free scans per personal period.
  static const freePerPeriod = 30;

  /// Credits granted per referral event, on each side.
  static const referralCredit = 300;

  /// Slips imported before this moment never consume credits — the migration
  /// guard so months scanned under the old (calendar-month Pro) scheme can't
  /// retroactively eat a user's new credit balance. Set to the membership-v2
  /// release date.
  static final DateTime creditsEpoch = DateTime(2026, 7, 13);

  /// The anchor: local midnight after the signup day. Free counting starts
  /// here, and photos taken before it are free backfill.
  /// (DateTime normalises day overflow, so a signup on the month's last day
  /// anchors on the 1st of the next month.)
  static DateTime anchorFor(DateTime signupLocal) =>
      DateTime(signupLocal.year, signupLocal.month, signupLocal.day + 1);

  /// Start of period [n] (n = 0 is [anchor] itself): anchor + n months with
  /// end-of-month clamping, always derived from the original anchor day —
  /// never compounding — so anchor 31/1 → 28/2 → 31/3 → 30/4. (This is why
  /// AppDate.addMonths, which lets 31 Feb overflow into 3 Mar, is not used.)
  static DateTime periodStart(DateTime anchor, int n) {
    final m0 = anchor.year * 12 + (anchor.month - 1) + n;
    final y = m0 ~/ 12;
    final m = m0 % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, anchor.day <= lastDay ? anchor.day : lastDay);
  }

  /// Index of the period containing [when] (clamped to 0 before the anchor —
  /// on the signup day itself everything is backfill anyway). A boundary
  /// instant belongs to the period it starts.
  static int periodIndexFor(DateTime anchor, DateTime when) {
    if (when.isBefore(anchor)) return 0;
    // Month arithmetic lands within one of the true index; clamping can move
    // a boundary off the anchor's day-of-month, so correct by comparison.
    var n = (when.year * 12 + when.month) - (anchor.year * 12 + anchor.month);
    if (n < 0) return 0;
    while (n > 0 && when.isBefore(periodStart(anchor, n))) {
      n--;
    }
    while (!when.isBefore(periodStart(anchor, n + 1))) {
      n++;
    }
    return n;
  }

  /// [start, end) of the period containing [now].
  static ({DateTime start, DateTime end}) currentPeriod(
    DateTime anchor,
    DateTime now,
  ) {
    final n = periodIndexFor(anchor, now);
    return (
      start: periodStart(anchor, n),
      end: periodStart(anchor, n + 1),
    );
  }

  /// Bucket countable slip import times into periods and derive both the
  /// current period's free usage and the all-time credit consumption.
  /// [createdAtsMs] must already be filtered to countable slips (non-deleted,
  /// not backfill, since [creditsEpoch], outside any Ultra window) — that
  /// filtering lives in the DB query.
  static QuotaUsage usage({
    required DateTime anchor,
    required List<int> createdAtsMs,
    required DateTime now,
  }) {
    final counts = <int, int>{};
    for (final ms in createdAtsMs) {
      final t = DateTime.fromMillisecondsSinceEpoch(ms);
      final n = periodIndexFor(anchor, t);
      counts[n] = (counts[n] ?? 0) + 1;
    }
    var creditsUsed = 0;
    for (final c in counts.values) {
      if (c > freePerPeriod) creditsUsed += c - freePerPeriod;
    }
    return QuotaUsage(
      freeUsedThisPeriod: counts[periodIndexFor(anchor, now)] ?? 0,
      creditsUsed: creditsUsed,
    );
  }

  /// End (exclusive, epoch ms) of the Ultra exemption window derived from the
  /// synced `ultraUntil` 'YYYY-MM-DD' (inclusive day): local midnight after
  /// that day. 0 when never Ultra / unparseable — nothing is exempt.
  static int ultraExemptEndMs(String ultraUntil) {
    if (ultraUntil.isEmpty) return 0;
    final parts = ultraUntil.split('-');
    if (parts.length != 3) return 0;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return 0;
    return DateTime(y, m, d + 1).millisecondsSinceEpoch;
  }
}
