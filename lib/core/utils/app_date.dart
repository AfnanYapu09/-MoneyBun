import 'package:intl/intl.dart';

/// Date helpers, including Thai Buddhist-era (พ.ศ. = ค.ศ. + 543) support.
class AppDate {
  const AppDate._();

  static const int buddhistOffset = 543;

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  // Day-based arithmetic below is CALENDAR arithmetic — `DateTime(y, m, d ± n)`
  // — never `add/subtract(Duration(days: n))`. A Duration is exactly n×24h, so
  // in a timezone with DST it can land an hour short of (or past) the intended
  // calendar day, which shifted weeks, dropped Saturday-night transactions from
  // week totals and made "next week" not move. Thailand has no DST, but the
  // device timezone is whatever the user set.

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  /// End of the month (last day, 23:59:59.999) containing [d].
  /// (Day 0 of month m+1 is the last day of month m.)
  static DateTime endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 0, 23, 59, 59, 999);

  static DateTime addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  static DateTime addYears(DateTime d, int years) =>
      DateTime(d.year + years, d.month, d.day);

  static DateTime startOfYear(DateTime d) => DateTime(d.year);

  static DateTime endOfYear(DateTime d) =>
      DateTime(d.year, 12, 31, 23, 59, 59, 999);

  /// Number of days in the calendar month containing [d].
  static int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

  /// Number of days in [year] (366 on leap years).
  static int daysInYear(int year) =>
      DateTime.utc(year, 12, 31).difference(DateTime.utc(year, 1, 1)).inDays +
      1;

  /// Whole calendar days from [from] to [to], by date parts only. Computed in
  /// UTC so a DST hop between the two local midnights can't make the count come
  /// up a day short.
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  // ---- Weeks (Sunday-first, the Thai convention) -------------------------

  /// Start of the week (Sunday 00:00) containing [d]. `weekday` is 1..7 with
  /// Mon=1 … Sun=7, so `weekday % 7` is the number of days since Sunday.
  static DateTime startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - d.weekday % 7);

  /// End of the week (Saturday 23:59:59.999) containing [d].
  static DateTime endOfWeek(DateTime d) {
    final s = startOfWeek(d);
    return DateTime(s.year, s.month, s.day + 6, 23, 59, 59, 999);
  }

  static DateTime addWeeks(DateTime d, int weeks) => DateTime(
        d.year,
        d.month,
        d.day + 7 * weeks,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      );

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `15 มิ.ย. 2569` (Buddhist era) or `15 Jun 2026` depending on [locale].
  static String formatDay(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    final df = DateFormat('d MMM', isThai ? 'th_TH' : 'en_US');
    final year = isThai ? d.year + buddhistOffset : d.year;
    return '${df.format(d)} $year';
  }

  /// Weekday + day header for the daily list, e.g. `จันทร์ 15 มิ.ย.`.
  static String formatDayHeader(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('EEEE d MMM', isThai ? 'th_TH' : 'en_US').format(d);
  }

  /// Year only, in the right era: `2569` (พ.ศ.) / `2026`.
  static String formatYear(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return '${isThai ? d.year + buddhistOffset : d.year}';
  }

  static String formatMonth(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    final df = DateFormat('MMMM', isThai ? 'th_TH' : 'en_US');
    final year = isThai ? d.year + buddhistOffset : d.year;
    return '${df.format(d)} $year';
  }

  /// Full month name, no year: `มีนาคม` / `March`.
  static String formatMonthName(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('MMMM', isThai ? 'th_TH' : 'en_US').format(d);
  }

  /// Abbreviated month: `มี.ค.` / `Mar`.
  static String formatMonthShort(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('MMM', isThai ? 'th_TH' : 'en_US').format(d);
  }

  static String formatTime(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('HH:mm', isThai ? 'th_TH' : 'en_US').format(d);
  }

  /// A week's range, e.g. `9–15 มิ.ย. 2569`. Collapses the month when both ends
  /// share it (`30 มิ.ย.–6 ก.ค. 2569` when they differ). [weekStart] is the
  /// Sunday; the week ends the following Saturday.
  static String formatWeekRange(DateTime weekStart, {required String locale}) {
    final isThai = locale.startsWith('th');
    final start = startOfWeek(weekStart);
    final end = DateTime(start.year, start.month, start.day + 6);
    final tag = isThai ? 'th_TH' : 'en_US';
    final dayFmt = DateFormat('d', tag);
    final monthFmt = DateFormat('MMM', tag);
    final year = isThai ? end.year + buddhistOffset : end.year;
    if (start.month == end.month) {
      return '${dayFmt.format(start)}–${dayFmt.format(end)} '
          '${monthFmt.format(end)} $year';
    }
    // A week straddling New Year carries a year on each side, so 28 Dec isn't
    // labelled with January's year.
    if (start.year != end.year) {
      final startYear = isThai ? start.year + buddhistOffset : start.year;
      return '${dayFmt.format(start)} ${monthFmt.format(start)} $startYear–'
          '${dayFmt.format(end)} ${monthFmt.format(end)} $year';
    }
    return '${dayFmt.format(start)} ${monthFmt.format(start)}–'
        '${dayFmt.format(end)} ${monthFmt.format(end)} $year';
  }

  /// Short day + month, no year: `18 มิ.ย.` / `18 Jun`.
  static String formatDayShort(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('d MMM', isThai ? 'th_TH' : 'en_US').format(d);
  }

  /// Full weekday name: `อังคาร` / `Tuesday`.
  static String formatWeekday(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    return DateFormat('EEEE', isThai ? 'th_TH' : 'en_US').format(d);
  }

  /// "วันนี้" / "เมื่อวาน" / short date, for day-group headers.
  static String relativeDayLabel(DateTime d, {required String locale}) {
    final isThai = locale.startsWith('th');
    final diff = daysBetween(d, DateTime.now());
    if (diff == 0) return isThai ? 'วันนี้' : 'Today';
    if (diff == 1) return isThai ? 'เมื่อวาน' : 'Yesterday';
    return formatDayShort(d, locale: locale);
  }

  static int toMillis(DateTime d) => d.millisecondsSinceEpoch;

  static DateTime fromMillis(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  /// Convert a year that may be Buddhist-era into Gregorian (CE).
  /// Heuristic: years >= 2400 are treated as พ.ศ. and shifted back by 543.
  static int normalizeYear(int year) =>
      year >= 2400 ? year - buddhistOffset : year;
}
