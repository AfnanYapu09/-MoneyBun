import 'package:flutter/material.dart';

import '../../../../core/constants/bank_codes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/icon_chip.dart';
import '../../../../core/widgets/slip_image.dart';
import '../../../../data/local/database.dart';
import '../../../../domain/enums/enums.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// True when the slip's sender and receiver names match (own-account move).
bool isSelfTransfer(SlipRow? slip) {
  String norm(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final a = norm(slip?.senderName);
  return a.isNotEmpty && a == norm(slip?.receiverName);
}

/// Read-only account → counterparty flow card. When the slip carries bank /
/// sender / receiver info we show the real bank → bank / name → name money
/// flow; otherwise we fall back to account → merchant (expense) / sender
/// (income) / destination account (transfer). The right side is hidden when
/// unknown.
Widget accountFlowFor({
  required TxnType type,
  required Map<String, AccountRow> accounts,
  required AppLocalizations l10n,
  String? accountId,
  String? toAccountId,
  SlipRow? slip,
}) {
  final account = accountId == null ? null : accounts[accountId]?.name;

  final fromBank = BankCodes.byCode(slip?.senderBank)?.nameTh;
  final toBank = BankCodes.byCode(slip?.receiverBank)?.nameTh;
  if (fromBank != null || toBank != null) {
    final sender = slip?.senderName;
    final receiver = slip?.receiverName;
    final hasSender = sender != null && sender.isNotEmpty;
    final hasReceiver = receiver != null && receiver.isNotEmpty;
    return AccountFlowCard(
      fromIcon: AppIcons.landmark,
      fromLabel: fromBank ?? l10n.txnFlowFrom,
      fromName: hasSender ? sender : (account ?? l10n.txnFlowAccount),
      toIcon: AppIcons.landmark,
      toLabel: toBank ?? l10n.txnFlowInto,
      toName: hasReceiver ? receiver : toBank,
    );
  }

  switch (type) {
    case TxnType.transfer:
      return AccountFlowCard(
        fromLabel: l10n.txnFlowPaidFrom,
        fromName: account ?? l10n.txnFlowAccount,
        toLabel: l10n.txnFlowTo,
        toName: (toAccountId == null ? null : accounts[toAccountId]?.name) ??
            l10n.txnFlowAccount,
      );
    case TxnType.income:
      final sender = slip?.senderName;
      final hasSender = sender != null && sender.isNotEmpty;
      return AccountFlowCard(
        fromLabel: l10n.txnFlowInto,
        fromName: account ?? l10n.txnFlowAccount,
        toLabel: hasSender ? l10n.txnFlowSender : null,
        toName: hasSender ? sender : null,
        toIcon: AppIcons.userRound,
      );
    case TxnType.expense:
      final merchant = slip?.receiverName;
      final hasMerchant = merchant != null && merchant.isNotEmpty;
      return AccountFlowCard(
        fromLabel: l10n.txnFlowPaidFrom,
        fromName: account ?? l10n.txnFlowCash,
        toLabel: hasMerchant ? l10n.txnFlowMerchant : null,
        toName: hasMerchant ? merchant : null,
        toIcon: AppIcons.store,
      );
  }
}

class AccountFlowCard extends StatelessWidget {
  const AccountFlowCard({
    super.key,
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
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.line),
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
                              size: 11.5, color: context.palette.ink3)),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(AppIcons.arrowRight,
                  size: 18, color: context.palette.ink3),
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
                                size: 11.5, color: context.palette.ink3)),
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
                    background: context.palette.surfaceAlt,
                    foreground: context.palette.ink2,
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
class SlipChip extends StatelessWidget {
  const SlipChip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.palette.line),
        ),
        child: Row(
          children: [
            const IconChip(
                icon: AppIcons.receiptText, size: 40, radius: 11, iconSize: 19),
            const SizedBox(width: 14),
            Expanded(
              child:
                  Text(l10n.txnSlipOriginal, style: AppTypography.body(size: 14.5)),
            ),
            Text(l10n.txnViewImage,
                style: AppTypography.heading(
                    size: 13, weight: FontWeight.w400, color: AppColors.terra)),
          ],
        ),
      ),
    );
  }
}

/// Full-screen viewer for the stored slip image. Pass [onDelete] to show a
/// "ลบรายการ" button (e.g. for a slip whose amount couldn't be read).
void showSlipViewer(BuildContext context, SlipRow slip,
    {VoidCallback? onDelete}) {
  final l10n = AppLocalizations.of(context);
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
              icon: const Icon(AppIcons.x, color: AppColors.reverse, size: 26),
            ),
          ),
          if (onDelete != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () {
                    Navigator.pop(c);
                    onDelete();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.trash2,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(l10n.txnDeleteEntry,
                            style: AppTypography.heading(
                                size: 14,
                                weight: FontWeight.w500,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
