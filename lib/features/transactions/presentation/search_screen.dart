import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../data/local/database.dart';
import 'txn_display.dart';
import 'widgets/txn_row.dart';

/// Search across all transactions (note + category name).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  final List<String> _recent = [];

  void _runQuery(String v) {
    setState(() => _query = v);
    final t = v.trim();
    if (t.isNotEmpty) {
      _recent
        ..remove(t)
        ..insert(0, t);
      if (_recent.length > 6) _recent.removeLast();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).languageCode;
    final txns = ref.watch(allTransactionsProvider).value ?? const [];
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };

    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <TransactionRow>[]
        : txns.where((t) {
            final cat = t.categoryId == null
                ? ''
                : categories[t.categoryId]?.name ?? '';
            return (t.note ?? '').toLowerCase().contains(q) ||
                cat.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(AppIcons.arrowLeft, size: 24),
                  ),
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.terra, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(AppIcons.search,
                              size: 18, color: AppColors.ink3),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (v) => setState(() => _query = v),
                              onSubmitted: _runQuery,
                              style: AppTypography.body(size: 14.5),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'ค้นหารายการ…',
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            InkWell(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(AppIcons.x,
                                  size: 18, color: AppColors.ink3),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: q.isEmpty
                  ? _RecentSearches(
                      recent: _recent.isNotEmpty
                          ? _recent
                          : categories.values
                              .take(3)
                              .map((c) => c.name)
                              .toList(),
                      onTap: (s) {
                        _controller.text = s;
                        setState(() => _query = s);
                      },
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('ผลการค้นหา · ${results.length} รายการ',
                              style: AppTypography.heading(
                                  size: 14, weight: FontWeight.w500)),
                        ),
                        for (var i = 0; i < results.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Builder(builder: (context) {
                            final t = results[i];
                            final d = txnDisplay(t,
                                categories: categories,
                                accounts: accounts,
                                locale: locale,
                                withDate: true);
                            return TxnRow(
                              icon: d.icon,
                              title: d.title,
                              sub: d.sub,
                              iconColor: d.color,
                              amountCents: t.amountCents,
                              type: t.type,
                              onTap: () => showAddTransactionSheet(context,
                                  editId: t.id),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "ค้นหาล่าสุด" chips shown when the query is empty.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.recent, required this.onTap});
  final List<String> recent;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return Center(
        child: Text('พิมพ์เพื่อค้นหารายการ',
            style: AppTypography.body(size: 14, color: AppColors.ink3)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('ค้นหาล่าสุด',
              style: AppTypography.heading(
                  size: 13, weight: FontWeight.w500, color: AppColors.ink3)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in recent)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(r),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.clock,
                          size: 14, color: AppColors.ink3),
                      const SizedBox(width: 6),
                      Text(r,
                          style: AppTypography.body(
                              size: 13.5, color: AppColors.ink2)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
