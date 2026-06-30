import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/enums/enums.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/app_date.dart';
import '../utils/money.dart';

/// Expense totals per day of the week starting [weekStart] (Sun→Sat, 7 slots).
/// Feeds [WeekStrip.dailyExpenseCents].
List<int> weeklyExpenseCents(DateTime weekStart, List<TransactionRow> txns) {
  final start = AppDate.startOfWeek(weekStart);
  final daily = List<int>.filled(7, 0);
  for (final t in txns) {
    if (t.type != TxnType.expense) continue;
    final i = AppDate.startOfDay(AppDate.fromMillis(t.occurredAt))
        .difference(start)
        .inDays;
    if (i >= 0 && i < 7) daily[i] += t.amountCents;
  }
  return daily;
}

/// A 7-day strip (Sun→Sat) for week mode: one column per day showing the day
/// number, a proportional bar of that day's expense, and the amount. Today is
/// highlighted. [dailyExpenseCents] has length 7 indexed from Sunday.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.dailyExpenseCents,
    required this.locale,
  });

  final DateTime weekStart;
  final List<int> dailyExpenseCents;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final start = AppDate.startOfWeek(weekStart);
    final today = AppDate.startOfDay(DateTime.now());
    final maxCents = dailyExpenseCents.fold<int>(0, (m, c) => c > m ? c : m);
    final isThai = locale.startsWith('th');
    // Sun..Sat initials.
    final labels = isThai
        ? const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
        : const ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayColumn(
                label: labels[i],
                day: start.add(Duration(days: i)),
                cents: dailyExpenseCents[i],
                fraction: maxCents == 0 ? 0.0 : dailyExpenseCents[i] / maxCents,
                isToday: AppDate.isSameDay(start.add(Duration(days: i)), today),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.label,
    required this.day,
    required this.cents,
    required this.fraction,
    required this.isToday,
  });

  final String label;
  final DateTime day;
  final int cents;
  final double fraction;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final barColor = cents == 0
        ? context.palette.surfaceAlt
        : (isToday ? AppColors.terra : context.palette.terraWash);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cents == 0 ? '–' : Money.compact(cents),
              maxLines: 1,
              style: AppTypography.body(
                  size: 9.5,
                  color:
                      cents == 0 ? context.palette.ink3 : context.palette.ink2),
            ),
          ),
          const SizedBox(height: 4),
          // Proportional bar (min height so empty days still read as a column).
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 14,
              height: 6 + 42 * fraction.clamp(0.0, 1.0),
              color: barColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isToday ? AppColors.terra : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: AppTypography.heading(
                size: 11.5,
                weight: FontWeight.w500,
                color: isToday ? AppColors.reverse : context.palette.ink2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.body(size: 10, color: context.palette.ink3),
          ),
        ],
      ),
    );
  }
}
