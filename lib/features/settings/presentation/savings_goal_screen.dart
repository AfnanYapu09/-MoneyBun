import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../domain/enums/enums.dart';

class SavingsGoalScreen extends ConsumerStatefulWidget {
  const SavingsGoalScreen({super.key});

  @override
  ConsumerState<SavingsGoalScreen> createState() => _SavingsGoalScreenState();
}

class _SavingsGoalScreenState extends ConsumerState<SavingsGoalScreen> {
  final _amount = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).value;
    if (!_init && settings != null) {
      if (settings.savingsGoalCents > 0) {
        _amount.text = (settings.savingsGoalCents ~/ 100).toString();
      }
      _init = true;
    }
    final goal = settings?.savingsGoalCents ?? 0;
    final txns = ref.watch(monthTransactionsProvider).value ?? const [];
    final income = txns
        .where((t) => t.type == TxnType.income)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final expense = txns
        .where((t) => t.type == TxnType.expense)
        .fold<int>(0, (s, t) => s + t.amountCents);
    final saved = income - expense;
    final pct = goal > 0 ? (saved / goal).clamp(0.0, 1.0) : 0.0;

    return SubScreenScaffold(
      title: 'เป้าหมายการออม',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.greenTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เก็บได้เดือนนี้',
                    style:
                        AppTypography.body(size: 13, color: AppColors.green)),
                const SizedBox(height: 2),
                Text(
                  goal > 0
                      ? '${Money.compact(saved)} / ${Money.compact(goal)}'
                      : Money.compact(saved),
                  style: AppTypography.heading(
                      size: 28,
                      weight: FontWeight.w600,
                      color: AppColors.green),
                ),
                if (goal > 0) ...[
                  const SizedBox(height: 12),
                  ProgressBar(
                    value: pct,
                    color: AppColors.green,
                    track: AppColors.green.withValues(alpha: 0.2),
                    height: 8,
                  ),
                  const SizedBox(height: 6),
                  Text('ถึงเป้า ${(pct * 100).round()}%',
                      style: AppTypography.body(
                          size: 12.5, color: AppColors.green)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('เป้าหมายต่อเดือน',
              style: AppTypography.body(size: 12.5, color: AppColors.ink3)),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration:
                const InputDecoration(prefixText: '฿ ', hintText: '8,000'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final a in const [5000, 8000, 10000, 15000]) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => _amount.text = a.toString(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text('฿${a ~/ 1000}k',
                          style: AppTypography.heading(
                              size: 13,
                              weight: FontWeight.w500,
                              color: AppColors.ink2)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: 'บันทึกเป้าหมาย', onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final cents = Money.parseToCents(_amount.text) ?? 0;
    await ref.read(settingsRepositoryProvider).setSavingsGoal(cents);
    if (mounted) context.pop();
  }
}
