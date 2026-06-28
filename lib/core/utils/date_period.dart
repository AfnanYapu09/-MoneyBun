import 'app_date.dart';

/// Which span the shared time filter is showing. UI-only state — NOT persisted,
/// so (unlike the enums in `domain/enums`) the order here carries no meaning.
enum PeriodMode { month, week, year }

/// The time window shown across Home / Stats / Budget / All-transactions.
///
/// A period is a [mode] plus an [anchor] normalised to the start of that span
/// (start-of-month, the Sunday that starts the week, or start-of-year).
/// Everything else — the millisecond bounds, the label, navigation — derives
/// from those two.
class DatePeriod {
  const DatePeriod._(this.mode, this.anchor);

  factory DatePeriod.month(DateTime d) =>
      DatePeriod._(PeriodMode.month, AppDate.startOfMonth(d));

  factory DatePeriod.week(DateTime d) =>
      DatePeriod._(PeriodMode.week, AppDate.startOfWeek(d));

  factory DatePeriod.year(DateTime d) =>
      DatePeriod._(PeriodMode.year, AppDate.startOfYear(d));

  final PeriodMode mode;
  final DateTime anchor;

  bool get isMonth => mode == PeriodMode.month;
  bool get isWeek => mode == PeriodMode.week;
  bool get isYear => mode == PeriodMode.year;

  /// Inclusive lower bound (epoch millis).
  int get start => AppDate.toMillis(anchor);

  /// Inclusive upper bound (epoch millis).
  int get end => AppDate.toMillis(switch (mode) {
        PeriodMode.month => AppDate.endOfMonth(anchor),
        PeriodMode.week => AppDate.endOfWeek(anchor),
        PeriodMode.year => AppDate.endOfYear(anchor),
      });

  /// The calendar month this period sits in — used by month-only views
  /// (Savings goal) regardless of the active mode.
  DateTime get monthAnchor => AppDate.startOfMonth(anchor);

  /// Number of days spanned by this window. Drives budget conversion
  /// (see `budget_math.dart`).
  int get windowDays => switch (mode) {
        PeriodMode.month => AppDate.daysInMonth(anchor),
        PeriodMode.week => 7,
        PeriodMode.year => AppDate.daysInYear(anchor.year),
      };

  DatePeriod next() => switch (mode) {
        PeriodMode.month => DatePeriod.month(AppDate.addMonths(anchor, 1)),
        PeriodMode.week => DatePeriod.week(AppDate.addWeeks(anchor, 1)),
        PeriodMode.year => DatePeriod.year(AppDate.addYears(anchor, 1)),
      };

  DatePeriod previous() => switch (mode) {
        PeriodMode.month => DatePeriod.month(AppDate.addMonths(anchor, -1)),
        PeriodMode.week => DatePeriod.week(AppDate.addWeeks(anchor, -1)),
        PeriodMode.year => DatePeriod.year(AppDate.addYears(anchor, -1)),
      };

  /// Chip label: `มิถุนายน 2569` (month), `9–15 มิ.ย. 2569` (week), `2569` (year).
  String label(String locale) => switch (mode) {
        PeriodMode.month => AppDate.formatMonth(anchor, locale: locale),
        PeriodMode.week => AppDate.formatWeekRange(anchor, locale: locale),
        PeriodMode.year => AppDate.formatYear(anchor, locale: locale),
      };

  /// Trailing noun for subtitles: `เดือนนี้` / `สัปดาห์นี้` / `ปีนี้`.
  String periodNoun(String locale) {
    final isThai = locale.startsWith('th');
    return switch (mode) {
      PeriodMode.month => isThai ? 'เดือนนี้' : 'this month',
      PeriodMode.week => isThai ? 'สัปดาห์นี้' : 'this week',
      PeriodMode.year => isThai ? 'ปีนี้' : 'this year',
    };
  }

  /// `สิ้นเดือน` / `สิ้นสัปดาห์` / `สิ้นปี` — used by the "X days left" label.
  String periodEndNoun(String locale) {
    final isThai = locale.startsWith('th');
    return switch (mode) {
      PeriodMode.month => isThai ? 'สิ้นเดือน' : 'end of month',
      PeriodMode.week => isThai ? 'สิ้นสัปดาห์' : 'end of week',
      PeriodMode.year => isThai ? 'สิ้นปี' : 'end of year',
    };
  }

  /// Comparison noun for the previous span: `เดือนก่อน` / `สัปดาห์ก่อน` / `ปีก่อน`.
  String previousNoun(String locale) {
    final isThai = locale.startsWith('th');
    return switch (mode) {
      PeriodMode.month => isThai ? 'เดือนก่อน' : 'last month',
      PeriodMode.week => isThai ? 'สัปดาห์ก่อน' : 'last week',
      PeriodMode.year => isThai ? 'ปีก่อน' : 'last year',
    };
  }

  /// Days remaining until the period ends, counting today (so the final day
  /// reads "1 day left", not 0). Returns 0 once the period is fully past.
  int get daysRemaining {
    final last = AppDate.startOfDay(AppDate.fromMillis(end));
    final today = AppDate.startOfDay(DateTime.now());
    final diff = last.difference(today).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  @override
  bool operator ==(Object other) =>
      other is DatePeriod && other.mode == mode && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(mode, anchor);
}
