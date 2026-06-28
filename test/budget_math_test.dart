import 'package:flutter_test/flutter_test.dart';
import 'package:moneybun/core/utils/budget_math.dart';
import 'package:moneybun/core/utils/date_period.dart';
import 'package:moneybun/domain/enums/enums.dart';

void main() {
  // June 2026 has 30 days; 2026 is not a leap year (365 days).
  final monthView = DatePeriod.month(DateTime(2026, 6));
  final weekView = DatePeriod.week(DateTime(2026, 6, 14));
  final yearView = DatePeriod.year(DateTime(2026));

  group('budgetForWindow', () {
    test('a budget viewed in its own period is unchanged', () {
      expect(budgetForWindow(30000, BudgetPeriod.monthly, monthView), 30000);
      expect(budgetForWindow(7000, BudgetPeriod.weekly, weekView), 7000);
    });

    test('monthly budget prorates to a week (× 7 / days-in-month)', () {
      // 30000 / 30 days = 1000/day × 7 = 7000.
      expect(budgetForWindow(30000, BudgetPeriod.weekly, weekView), 30000);
      expect(budgetForWindow(30000, BudgetPeriod.monthly, weekView), 7000);
    });

    test('weekly budget scales up to a month', () {
      // 7000 / 7 = 1000/day × 30 = 30000.
      expect(budgetForWindow(7000, BudgetPeriod.weekly, monthView), 30000);
    });

    test('yearly budget scales to month and week', () {
      // 365000 / 365 = 1000/day.
      expect(budgetForWindow(365000, BudgetPeriod.yearly, monthView), 30000);
      expect(budgetForWindow(365000, BudgetPeriod.yearly, weekView), 7000);
    });

    test('a yearly view aggregates the smaller budgets', () {
      // Identity for yearly; monthly × 12; weekly × (365/7).
      expect(budgetForWindow(365000, BudgetPeriod.yearly, yearView), 365000);
      expect(budgetForWindow(30000, BudgetPeriod.monthly, yearView), 360000);
      expect(budgetForWindow(7000, BudgetPeriod.weekly, yearView), 365000);
    });
  });

  group('budgetPeriodLabel', () {
    test('thai labels', () {
      expect(budgetPeriodLabel(BudgetPeriod.weekly, 'th'), 'รายสัปดาห์');
      expect(budgetPeriodLabel(BudgetPeriod.monthly, 'th'), 'รายเดือน');
      expect(budgetPeriodLabel(BudgetPeriod.yearly, 'th'), 'รายปี');
    });
  });
}
