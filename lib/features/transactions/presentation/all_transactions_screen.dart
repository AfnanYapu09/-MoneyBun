import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/category_l10n.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/period_chip.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/account_flow.dart';
import 'widgets/txn_day_group.dart';

/// Full-screen list of all transactions for the selected month, grouped by day.
class AllTransactionsScreen extends ConsumerWidget {
  const AllTransactionsScreen({super.key, this.categoryId, this.tagId});

  /// When set, the list is filtered to a single category / tag — opened by
  /// tapping a row in the Stats breakdown. Mutually exclusive.
  final String? categoryId;
  final String? tagId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final period = ref.watch(selectedPeriodProvider);
    var txns = ref.watch(periodTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };

    // Optional single-category / single-tag filter (opened from Stats).
    String? filterName;
    if (categoryId != null) {
      txns = txns
          .where((t) => (t.categoryId ?? 'sys_other') == categoryId)
          .toList();
      filterName = categories[categoryId]?.displayName(locale) ?? l10n.txnOther;
    } else if (tagId != null) {
      final taggedIds = (ref.watch(allTransactionTagsProvider).value ??
              const <TransactionTagRow>[])
          .where((l) => l.tagId == tagId)
          .map((l) => l.transactionId)
          .toSet();
      txns = txns.where((t) => taggedIds.contains(t.id)).toList();
      final tags = {
        for (final tg in ref.watch(tagsProvider).value ?? const <TagRow>[])
          tg.id: tg
      };
      filterName = tags[tagId]?.name;
    }

    final byDay = groupBy<TransactionRow, DateTime>(
      txns,
      (t) => AppDate.startOfDay(AppDate.fromMillis(t.occurredAt)),
    );
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return SubScreenScaffold(
      title: filterName ?? l10n.txnAllTitle,
      action: IconButton(
        onPressed: () => context.push('/search'),
        icon: Icon(AppIcons.search, size: 21, color: context.palette.ink2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
        children: [
          PeriodChip(
            label: period.label(locale),
            onTapLabel: () => showPeriodPickerSheet(context),
            onPrev: () => ref.read(selectedPeriodProvider.notifier).previous(),
            onNext: () => ref.read(selectedPeriodProvider.notifier).next(),
          ),
          const SizedBox(height: 6),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text(l10n.txnNoneInPeriod(period.periodNoun(locale)),
                    style: AppTypography.body(
                        size: 14, color: context.palette.ink3)),
              ),
            ),
          for (final day in days)
            TxnDayGroup(
              day: day,
              rows: byDay[day]!,
              categories: categories,
              accounts: accounts,
              locale: locale,
              onTapTxn: (id) => showAddTransactionSheet(context, editId: id),
              onCategorize: (t) => _categorize(context, ref, t),
              onShowSlip: (t) => _showSlip(context, ref, t),
            ),
        ],
      ),
    );
  }

  /// Open the source slip for a row, with a "ลบรายการ" button — used by the
  /// zero-amount warning so the user can read or delete the failed import.
  Future<void> _showSlip(
      BuildContext context, WidgetRef ref, TransactionRow txn) async {
    final slip = txn.slipId == null
        ? null
        : await ref.read(slipRepositoryProvider).get(txn.slipId!);
    if (!context.mounted) return;
    if (slip == null) {
      showAddTransactionSheet(context, editId: txn.id);
      return;
    }
    showSlipViewer(
      context,
      slip,
      onDelete: () => ref.read(transactionRepositoryProvider).delete(txn.id),
    );
  }

  Future<void> _categorize(
      BuildContext context, WidgetRef ref, TransactionRow txn) async {
    final id = txn.id;
    final existing = await ref.read(transactionRepositoryProvider).tagIds(id);
    final slip = txn.slipId == null
        ? null
        : await ref.read(slipRepositoryProvider).get(txn.slipId!);
    if (!context.mounted) return;
    final pick = await showCategoryPicker(
      context,
      initialTagIds: existing,
      slip: slip,
      onTransfer: () =>
          ref.read(transactionRepositoryProvider).reclassifyAsTransfer(id),
    );
    if (pick != null) {
      await ref
          .read(transactionRepositoryProvider)
          .setCategory(id, pick.categoryId);
      await ref.read(databaseProvider).setTransactionTags(id, pick.tagIds);
    }
  }
}
