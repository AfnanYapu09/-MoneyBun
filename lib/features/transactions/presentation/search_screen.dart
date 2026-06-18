import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
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
                        border: Border.all(color: AppColors.line),
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
                              onChanged: (v) => setState(() => _query = v),
                              style: AppTypography.body(size: 14.5),
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                filled: false,
                                border: InputBorder.none,
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
                  ? Center(
                      child: Text('พิมพ์เพื่อค้นหารายการ',
                          style: AppTypography.body(
                              size: 14, color: AppColors.ink3)),
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
                                locale: locale);
                            return TxnRow(
                              icon: d.icon,
                              title: d.title,
                              sub: d.sub,
                              amountCents: t.amountCents,
                              type: t.type,
                              onTap: () =>
                                  context.push('/transactions/${t.id}'),
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
