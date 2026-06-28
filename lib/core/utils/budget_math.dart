import '../../domain/enums/enums.dart';
import 'app_date.dart';
import 'date_period.dart';

/// Convert a budget of [period] worth [amountCents] into the equivalent amount
/// for the viewing [window] (month / week / year).
///
/// We scale by how many of the budget's own period fit inside the window, which
/// keeps the identity cases exact (a monthly budget viewed by month, a weekly
/// budget viewed by week, a yearly budget viewed by year are all unchanged) and
/// scales the rest proportionally — e.g. a monthly budget viewed by year = ×12.
int budgetForWindow(int amountCents, BudgetPeriod period, DatePeriod window) {
  final units = switch (period) {
    BudgetPeriod.weekly => window.windowDays / 7,
    BudgetPeriod.monthly => _monthsInWindow(window),
    BudgetPeriod.yearly =>
      window.windowDays / AppDate.daysInYear(window.anchor.year),
  };
  return (amountCents * units).round();
}

/// How many calendar months the [window] represents (exact for month/year,
/// prorated by day for a week).
double _monthsInWindow(DatePeriod window) => switch (window.mode) {
      PeriodMode.month => 1,
      PeriodMode.week => 7 / AppDate.daysInMonth(window.anchor),
      PeriodMode.year => 12,
    };

/// Thai label for a budget period: `รายสัปดาห์` / `รายเดือน` / `รายปี`.
String budgetPeriodLabel(BudgetPeriod period, String locale) {
  final isThai = locale.startsWith('th');
  switch (period) {
    case BudgetPeriod.weekly:
      return isThai ? 'รายสัปดาห์' : 'weekly';
    case BudgetPeriod.monthly:
      return isThai ? 'รายเดือน' : 'monthly';
    case BudgetPeriod.yearly:
      return isThai ? 'รายปี' : 'yearly';
  }
}
