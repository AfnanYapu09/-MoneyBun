import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';

/// Settings → ส่งออกข้อมูล. Exports every transaction as a CSV: it is copied to
/// the clipboard (paste into Sheets / email / Line) and saved as a file so the
/// user can back up or move their data off the device.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final txns =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRow>[];
    return SubScreenScaffold(
      title: 'ส่งออกข้อมูล',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.palette.terraWash,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(AppIcons.download,
                  size: 30, color: context.palette.terraFg),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'ส่งออกรายการทั้งหมดเป็นไฟล์ CSV เพื่อสำรองข้อมูล '
                'หรือเปิดใน Excel / Google Sheets',
                textAlign: TextAlign.center,
                style:
                    AppTypography.body(size: 13.5, color: context.palette.ink2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.line),
            ),
            child: Row(
              children: [
                Icon(AppIcons.receiptText,
                    size: 20, color: context.palette.ink3),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('จำนวนรายการทั้งหมด',
                      style: AppTypography.body(size: 15)),
                ),
                Text('${txns.length}',
                    style: AppTypography.heading(
                        size: 16, weight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'ส่งออกเป็น CSV',
            icon: AppIcons.download,
            loading: _busy,
            onPressed: txns.isEmpty ? null : () => _export(txns),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'ไฟล์จะถูกคัดลอกไปยังคลิปบอร์ดและบันทึกในเครื่อง',
              style: AppTypography.body(size: 12, color: context.palette.ink3),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(List<TransactionRow> txns) async {
    setState(() => _busy = true);
    try {
      final categories = {
        for (final c
            in ref.read(categoriesProvider).value ?? const <CategoryRow>[])
          c.id: c
      };
      final csv = _buildCsv(txns, categories);

      String? savedPath;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/moneybun_export.csv');
        await file.writeAsString(csv);
        savedPath = file.path;
      } catch (_) {
        // Saving is best-effort; the clipboard copy below is the reliable path.
      }
      await Clipboard.setData(ClipboardData(text: csv));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedPath == null
              ? 'คัดลอกข้อมูล CSV ไปยังคลิปบอร์ดแล้ว'
              : 'คัดลอกไปคลิปบอร์ดแล้ว · บันทึกไฟล์ที่ $savedPath'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งออกไม่สำเร็จ')),
        );
      }
    } finally {
      // Always clear the spinner, even if the clipboard channel throws, so the
      // button can be retried.
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A spreadsheet-safe CSV: a fixed header, raw decimal amounts (no thousand
  /// separators that would split a column) and quoted text fields.
  String _buildCsv(
      List<TransactionRow> txns, Map<String, CategoryRow> categories) {
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final buffer = StringBuffer('date,type,amount,category,note\n');
    for (final t in txns) {
      final date = AppDate.fromMillis(t.occurredAt).toIso8601String();
      final amount = (t.amountCents / 100).toStringAsFixed(2);
      final category =
          t.categoryId == null ? '' : (categories[t.categoryId]?.name ?? '');
      buffer.writeln('$date,${t.type.name},$amount,'
          '${cell(category)},${cell(t.note ?? '')}');
    }
    return buffer.toString();
  }
}
