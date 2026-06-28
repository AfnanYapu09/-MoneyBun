import '../../domain/enums/enums.dart';
import 'app_date.dart';
import 'date_period.dart';

/// Convert a budget of [period] worth [amountCents] into the equivalent amount
/// for the viewing [window] (a month or a week), via a per-day rate.
///
/// This is what makes weekly / monthly / yearly budgets all comparable against
/// whatever range the user is looking at:
///   perDay = amount / (days in the budget's own period)
///   result = perDay × (days in the viewing window)
///
/// So a monthly budget viewed by month is unchanged, a weekly budget viewed by
/// week is unchanged, and everything else scales proportionally.
int budgetForWindow(int amountCents, BudgetPeriod period, DatePeriod window) {
  final periodDays = switch (period) {
    BudgetPeriod.weekly => 7.0,
    BudgetPeriod.monthly => AppDate.daysInMonth(window.anchor).toDouble(),
    BudgetPeriod.yearly => AppDate.daysInYear(window.anchor.year).toDouble(),
  };
  final perDay = amountCents / periodDays;
  return (perDay * window.windowDays).round();
}

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
