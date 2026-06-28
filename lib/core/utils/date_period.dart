import 'app_date.dart';

/// Which span the shared time filter is showing. UI-only state — NOT persisted,
/// so (unlike the enums in `domain/enums`) the order here carries no meaning.
enum PeriodMode { month, week }

/// The time window shown across Home / Stats / Budget / All-transactions.
///
/// A period is a [mode] plus an [anchor] normalised to the start of that span
/// (start-of-month, or the Sunday that starts the week). Everything else —
/// the millisecond bounds, the label, navigation — derives from those two.
class DatePeriod {
  const DatePeriod._(this.mode, this.anchor);

  factory DatePeriod.month(DateTime d) =>
      DatePeriod._(PeriodMode.month, AppDate.startOfMonth(d));

  factory DatePeriod.week(DateTime d) =>
      DatePeriod._(PeriodMode.week, AppDate.startOfWeek(d));

  final PeriodMode mode;
  final DateTime anchor;

  bool get isMonth => mode == PeriodMode.month;
  bool get isWeek => mode == PeriodMode.week;

  /// Inclusive lower bound (epoch millis).
  int get start => AppDate.toMillis(anchor);

  /// Inclusive upper bound (epoch millis).
  int get end => AppDate.toMillis(
        isMonth ? AppDate.endOfMonth(anchor) : AppDate.endOfWeek(anchor),
      );

  /// The calendar month this period sits in — used by month-only views
  /// (Comparison, Savings goal) regardless of the active mode.
  DateTime get monthAnchor => AppDate.startOfMonth(anchor);

  /// Number of days spanned by this window (month length, or 7 for a week).
  /// Drives budget conversion (see `budget_math.dart`).
  int get windowDays => isMonth ? AppDate.daysInMonth(anchor) : 7;

  DatePeriod next() => isMonth
      ? DatePeriod.month(AppDate.addMonths(anchor, 1))
      : DatePeriod.week(AppDate.addWeeks(anchor, 1));

  DatePeriod previous() => isMonth
      ? DatePeriod.month(AppDate.addMonths(anchor, -1))
      : DatePeriod.week(AppDate.addWeeks(anchor, -1));

  /// Chip label: `มิถุนายน 2569` (month) or `9–15 มิ.ย. 2569` (week).
  String label(String locale) => isMonth
      ? AppDate.formatMonth(anchor, locale: locale)
      : AppDate.formatWeekRange(anchor, locale: locale);

  /// Trailing noun for subtitles: `เดือนนี้` / `สัปดาห์นี้` (or English).
  String periodNoun(String locale) {
    final isThai = locale.startsWith('th');
    if (isMonth) return isThai ? 'เดือนนี้' : 'this month';
    return isThai ? 'สัปดาห์นี้' : 'this week';
  }

  /// `สิ้นเดือน` / `สิ้นสัปดาห์` — used by the "X days left" label.
  String periodEndNoun(String locale) {
    final isThai = locale.startsWith('th');
    if (isMonth) return isThai ? 'สิ้นเดือน' : 'end of month';
    return isThai ? 'สิ้นสัปดาห์' : 'end of week';
  }

  /// Days remaining until the period ends, counting today (so the final day
  /// reads "1 day left", not 0). Returns 0 once the period is fully past.
  int get daysRemaining {
    final last = AppDate.startOfDay(AppDate.fromMillis(end));
    final today = AppDate.startOfDay(DateTime.now());
    final diff = last.difference(today).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  /// Fraction of a monthly amount that falls within this period. 1.0 for a
  /// month; a week is prorated by `7 / daysInMonth` so weekly views can compare
  /// spending against monthly budgets fairly.
  double get monthlyProration =>
      isMonth ? 1.0 : 7 / AppDate.daysInMonth(anchor);

  @override
  bool operator ==(Object other) =>
      other is DatePeriod && other.mode == mode && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(mode, anchor);
}
