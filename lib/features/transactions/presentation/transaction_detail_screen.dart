import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/constants/bank_codes.dart';
import '../../../core/router/sheets.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/icon_chip.dart';
import '../../../core/widgets/slip_image.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../domain/enums/enums.dart';
import 'txn_display.dart';

/// Detail view for a single transaction.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).languageCode;
    final txn = ref.watch(transactionByIdProvider(id)).value;
    final categories = {
      for (final c
          in ref.watch(categoriesProvider).value ?? const <CategoryRow>[])
        c.id: c
    };
    final accounts = {
      for (final a in ref.watch(accountsProvider).value ?? const <AccountRow>[])
        a.id: a
    };
    final tags = {
      for (final t in ref.watch(tagsProvider).value ?? const <TagRow>[]) t.id: t
    };
    final links = ref.watch(allTransactionTagsProvider).value ?? const [];
    final slips =
        ref.watch(slipsByIdProvider).value ?? const <String, SlipRow>{};

    if (txn == null) {
      return const SubScreenScaffold(
        title: 'รายละเอียดรายการ',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final d = txnDisplay(txn,
        categories: categories,
        accounts: accounts,
        locale: locale,
        withTime: false);
    final category = txn.categoryId == null ? null : categories[txn.categoryId];
    final txnTags = links
        .where((l) => l.transactionId == id)
        .map((l) => tags[l.tagId]?.name)
        .whereType<String>()
        .toList();
    final (sign, color) = switch (txn.type) {
      TxnType.income => ('+', AppColors.green),
      TxnType.expense => ('−', AppColors.ink),
      TxnType.transfer => ('', AppColors.ink),
    };
    final catTag = [
      if (category != null) category.name,
      ...txnTags.map((t) => '#$t'),
    ].join(' · ');
    final slip = txn.slipId == null ? null : slips[txn.slipId];

    // A slip whose sender == receiver moves money between the user's own
    // accounts — promote it to a transfer so it stays out of spending stats.
    if (txn.type == TxnType.expense && _isSelfTransfer(slip)) {
      Future.microtask(() =>
          ref.read(transactionRepositoryProvider).reclassifyAsTransfer(id));
    }

    return SubScreenScaffold(
      title: 'รายละเอียดรายการ',
      action: IconButton(
        onPressed: () => showAddTransactionSheet(context, editId: id),
        icon: const Icon(AppIcons.pencil, size: 21, color: AppColors.terra),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
          // Hero
          Column(
            children: [
              IconChip(icon: d.icon, size: 64, radius: 20, iconSize: 30),
              const SizedBox(height: 10),
              Text('$sign${Money.compact(txn.amountCents.abs())}',
                  style: AppTypography.heading(
                      size: 36, weight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(d.title,
                  style: AppTypography.body(size: 15, color: AppColors.ink2)),
            ],
          ),
          const SizedBox(height: 24),
          if (txn.type != TxnType.transfer) ...[
            _card([
              _DetailRow(
                icon: AppIcons.layoutGrid,
                label: 'หมวดหมู่ / แท็ก',
                value: catTag.isEmpty ? 'ยังไม่จัดหมวด' : catTag,
                onTap: () => _pickCategory(context, ref),
              ),
            ]),
            const SizedBox(height: 18),
          ],
          Text('บัญชี',
              style: AppTypography.heading(
                  size: 13, weight: FontWeight.w500, color: AppColors.ink3)),
          const SizedBox(height: 8),
          _accountFlow(txn, accounts, slip),
          const SizedBox(height: 12),
          _card([
            _DetailRow(
              icon: AppIcons.calendar,
              label: 'วันที่',
              value:
                  '${AppDate.formatDay(AppDate.fromMillis(txn.occurredAt), locale: locale)} · ${AppDate.formatTime(AppDate.fromMillis(txn.occurredAt), locale: locale)}',
            ),
            if (txn.note != null && txn.note!.isNotEmpty)
              _DetailRow(
                  icon: AppIcons.pencilLine, label: 'โน้ต', value: txn.note!),
          ]),
          if (slip != null) ...[
            const SizedBox(height: 12),
            _SlipChip(onTap: () => _viewSlip(context, slip)),
          ],
          const SizedBox(height: 22),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _confirmDelete(context, ref),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.dangerWash,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(AppIcons.trash2,
                      size: 19, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text('ลบรายการนี้',
                      style: AppTypography.heading(
                          size: 16,
                          weight: FontWeight.w500,
                          color: AppColors.danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// True when the slip's sender and receiver names match (own-account move).
  bool _isSelfTransfer(SlipRow? slip) {
    String norm(String? s) =>
        (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final a = norm(slip?.senderName);
    return a.isNotEmpty && a == norm(slip?.receiverName);
  }

  /// Account → counterparty flow card. When the slip carries sender/receiver
  /// info we show the real bank → bank / name → name money flow; otherwise we
  /// fall back to account → merchant (expense) / sender (income) / destination
  /// account (transfer). The right side is hidden when unknown.
  Widget _accountFlow(
      TransactionRow txn, Map<String, AccountRow> accounts, SlipRow? slip) {
    final account = accounts[txn.accountId]?.name;

    // Bank-transfer slip (source/destination bank codes present): show the
    // real money flow — bank as the label, person as the name, on both sides.
    final fromBank = BankCodes.byCode(slip?.senderBank)?.nameTh;
    final toBank = BankCodes.byCode(slip?.receiverBank)?.nameTh;
    if (fromBank != null || toBank != null) {
      final sender = slip?.senderName;
      final receiver = slip?.receiverName;
      final hasSender = sender != null && sender.isNotEmpty;
      final hasReceiver = receiver != null && receiver.isNotEmpty;
      return _AccountFlow(
        fromIcon: AppIcons.landmark,
        fromLabel: fromBank ?? 'โอนจาก',
        fromName: hasSender ? sender : (account ?? 'บัญชี'),
        toIcon: AppIcons.landmark,
        toLabel: toBank ?? 'เข้าบัญชี',
        toName: hasReceiver ? receiver : toBank,
      );
    }

    switch (txn.type) {
      case TxnType.transfer:
        return _AccountFlow(
          fromLabel: 'จ่ายจาก',
          fromName: account ?? 'บัญชี',
          toLabel: 'ไปยัง',
          toName: accounts[txn.toAccountId]?.name ?? 'บัญชี',
        );
      case TxnType.income:
        final sender = slip?.senderName;
        final hasSender = sender != null && sender.isNotEmpty;
        return _AccountFlow(
          fromLabel: 'เข้าบัญชี',
          fromName: account ?? 'บัญชี',
          toLabel: hasSender ? 'จาก' : null,
          toName: hasSender ? sender : null,
          toIcon: AppIcons.userRound,
        );
      case TxnType.expense:
        final merchant = slip?.receiverName;
        final hasMerchant = merchant != null && merchant.isNotEmpty;
        return _AccountFlow(
          fromLabel: 'จ่ายจาก',
          fromName: account ?? 'เงินสด',
          toLabel: hasMerchant ? 'ร้านค้า' : null,
          toName: hasMerchant ? merchant : null,
          toIcon: AppIcons.store,
        );
    }
  }

  void _viewSlip(BuildContext context, SlipRow slip) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6211C18),
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  child: SlipImage(slip: slip, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: IconButton(
                onPressed: () => Navigator.pop(c),
                icon:
                    const Icon(AppIcons.x, color: AppColors.reverse, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, WidgetRef ref) async {
    final existing = await ref.read(transactionRepositoryProvider).tagIds(id);
    if (!context.mounted) return;
    final pick = await showCategoryPicker(context, initialTagIds: existing);
    if (pick != null) {
      await ref
          .read(transactionRepositoryProvider)
          .setCategory(id, pick.categoryId);
      await ref.read(databaseProvider).setTransactionTags(id, pick.tagIds);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text('ต้องการลบรายการนี้ใช่ไหม?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(transactionRepositoryProvider).delete(id);
      if (context.mounted) context.pop();
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.terra700),
          const SizedBox(width: 14),
          Text(label,
              style: AppTypography.body(size: 13.5, color: AppColors.ink3)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: AppTypography.body(size: 14.5)),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(AppIcons.chevronRight, size: 18, color: AppColors.ink3),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _AccountFlow extends StatelessWidget {
  const _AccountFlow({
    required this.fromLabel,
    required this.fromName,
    this.fromIcon = AppIcons.wallet,
    this.toLabel,
    this.toName,
    this.toIcon,
  });

  final String fromLabel;
  final String fromName;
  final IconData fromIcon;
  final String? toLabel;
  final String? toName;
  final IconData? toIcon;

  @override
  Widget build(BuildContext context) {
    final hasTo = toName != null && toName!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                IconChip(icon: fromIcon, size: 36, radius: 11, iconSize: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fromLabel,
                          style: AppTypography.body(
                              size: 11.5, color: AppColors.ink3)),
                      Text(fromName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.heading(
                              size: 14, weight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (hasTo) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(AppIcons.arrowRight, size: 18, color: AppColors.ink3),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(toLabel ?? '',
                            style: AppTypography.body(
                                size: 11.5, color: AppColors.ink3)),
                        Text(toName!,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading(
                                size: 14, weight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconChip(
                    icon: toIcon ?? AppIcons.store,
                    size: 36,
                    radius: 11,
                    iconSize: 18,
                    background: AppColors.paper2,
                    foreground: AppColors.ink2,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "สลิปต้นฉบับ / ดูรูป" chip — opens the stored slip image.
class _SlipChip extends StatelessWidget {
  const _SlipChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const IconChip(
                icon: AppIcons.receiptText, size: 40, radius: 11, iconSize: 19),
            const SizedBox(width: 14),
            Expanded(
              child: Text('สลิปต้นฉบับ', style: AppTypography.body(size: 14.5)),
            ),
            Text('ดูรูป',
                style: AppTypography.heading(
                    size: 13, weight: FontWeight.w400, color: AppColors.terra)),
          ],
        ),
      ),
    );
  }
}
