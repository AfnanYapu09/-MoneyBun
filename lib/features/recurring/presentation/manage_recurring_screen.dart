import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../core/widgets/swipe_action_row.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../plan/presentation/pro_gate.dart';

/// Settings → recurring entries. Lists the user's recurring rules and lets them
/// add new ones or delete existing ones (created transactions are untouched).
class ManageRecurringScreen extends ConsumerWidget {
  const ManageRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!ref.watch(planProvider).canUseRecurring) {
      return SubScreenScaffold(
        title: l10n.settingsRecurring,
        body: const ProFeatureGate(),
      );
    }
    final locale = Localizations.localeOf(context).languageCode;
    final rules =
        ref.watch(recurringRulesProvider).value ?? const <RecurringRuleRow>[];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c,
    };

    return SubScreenScaffold(
      title: l10n.recurManageTitle,
      footer: PrimaryButton(
        label: l10n.recurAdd,
        icon: AppIcons.plus,
        onPressed: () => showRecurringRuleSheet(context),
      ),
      body: rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.recurEmpty,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    size: 14,
                    color: context.palette.ink3,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: rules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = rules[i];
                final cat =
                    r.categoryId == null ? null : categories[r.categoryId];
                final title = cat?.displayName(locale) ??
                    (r.type == TxnType.income ? l10n.income : l10n.expense);
                final next = AppDate.formatDayHeader(
                  AppDate.fromMillis(r.nextRunAt),
                  locale: locale,
                );
                // The card stays put; its CONTENT slides left inside (over
                // the surface), matching the transaction lists' look.
                return Container(
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SwipeActionRow(
                    key: ValueKey('recur-swipe-${r.id}'),
                    onDeleteTap: () => _confirmDelete(context, ref, r.id),
                    child: InkWell(
                      // Tap to edit the rule in the same sheet used to create.
                      onTap: () => showRecurringRuleSheet(context, rule: r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const IconChip(
                              icon: AppIcons.repeat,
                              size: 38,
                              radius: 12,
                              iconSize: 19,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTypography.heading(
                                      size: 15,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_freqLabel(l10n, r.freq)} · '
                                    '${l10n.recurNextRun} $next',
                                    style: AppTypography.body(
                                      size: 12.5,
                                      color: context.palette.ink3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Money.format(r.amountCents),
                              style: AppTypography.heading(
                                size: 15,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _freqLabel(AppLocalizations l10n, RecurFreq f) => switch (f) {
        RecurFreq.daily => l10n.recurFreqDaily,
        RecurFreq.weekly => l10n.recurFreqWeekly,
        RecurFreq.monthly => l10n.recurFreqMonthly,
      };

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Captured before the await — ref.read after the dialog would throw if the
    // auth-state redirect unmounted this screen while the dialog was up.
    final db = ref.read(databaseProvider);
    final ok = await confirmDeleteTxn(
      context,
      title: l10n.recurManageTitle,
      body: l10n.recurConfirmDelete,
    );
    if (ok) {
      await db.softDeleteRecurringRule(
        id,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
}
