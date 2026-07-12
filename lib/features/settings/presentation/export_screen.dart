import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/local/database.dart';
import '../../../l10n/generated/app_localizations.dart';

enum _ExportRange { all, day, month, year }

/// Settings → ส่งออกข้อมูล. Pick a range (everything / a day / a month / a
/// year) and export the entries as an Excel file shared through the system
/// share sheet; a CSV clipboard copy remains as the lightweight fallback.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _busy = false;
  _ExportRange _range = _ExportRange.all;
  DateTime _anchor = DateTime.now();

  /// (start inclusive, end exclusive) millis for the selected range, or null
  /// for everything.
  (int, int)? get _window => switch (_range) {
        _ExportRange.all => null,
        _ExportRange.day => (
            AppDate.toMillis(
                DateTime(_anchor.year, _anchor.month, _anchor.day)),
            AppDate.toMillis(
              DateTime(_anchor.year, _anchor.month, _anchor.day + 1),
            ),
          ),
        _ExportRange.month => (
            AppDate.toMillis(DateTime(_anchor.year, _anchor.month)),
            AppDate.toMillis(DateTime(_anchor.year, _anchor.month + 1)),
          ),
        _ExportRange.year => (
            AppDate.toMillis(DateTime(_anchor.year)),
            AppDate.toMillis(DateTime(_anchor.year + 1)),
          ),
      };

  String _rangeLabel(String locale) => switch (_range) {
        _ExportRange.all => '',
        _ExportRange.day =>
          DateFormat.yMMMMd(locale == 'th' ? 'th' : 'en').format(_anchor),
        _ExportRange.month =>
          DateFormat.yMMMM(locale == 'th' ? 'th' : 'en').format(_anchor),
        _ExportRange.year =>
          DateFormat.y(locale == 'th' ? 'th' : 'en').format(_anchor),
      };

  String get _fileSuffix => switch (_range) {
        _ExportRange.all => 'all',
        _ExportRange.day => DateFormat('yyyy-MM-dd').format(_anchor),
        _ExportRange.month => DateFormat('yyyy-MM').format(_anchor),
        _ExportRange.year => DateFormat('yyyy').format(_anchor),
      };

  List<TransactionRow> _filtered(List<TransactionRow> txns) {
    final w = _window;
    if (w == null) return txns;
    return txns
        .where((t) => t.occurredAt >= w.$1 && t.occurredAt < w.$2)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final txns =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRow>[];
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    final selected = _filtered(txns);

    return SubScreenScaffold(
      title: l10n.settingsExportData,
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
              child: Icon(
                AppIcons.download,
                size: 30,
                color: context.palette.terraFg,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                l10n.settingsExportDescription,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  size: 13.5,
                  color: context.palette.ink2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsExportRange,
            style: AppTypography.body(size: 13, color: context.palette.ink3),
          ),
          const SizedBox(height: 8),
          SegmentedControl<_ExportRange>(
            value: _range,
            onChanged: (r) => setState(() => _range = r),
            segments: [
              Segment(value: _ExportRange.all, label: l10n.exportRangeAll),
              Segment(value: _ExportRange.day, label: l10n.exportRangeDay),
              Segment(value: _ExportRange.month, label: l10n.exportRangeMonth),
              Segment(value: _ExportRange.year, label: l10n.exportRangeYear),
            ],
          ),
          if (_range != _ExportRange.all) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickAnchor,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.palette.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 19,
                      color: context.palette.terraFg,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _rangeLabel(locale),
                        style: AppTypography.heading(
                          size: 15,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: 19,
                      color: context.palette.ink3,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.palette.line),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.receiptText,
                  size: 20,
                  color: context.palette.ink3,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsTotalTransactions,
                    style: AppTypography.body(size: 15),
                  ),
                ),
                Text(
                  '${selected.length}',
                  style: AppTypography.heading(
                    size: 16,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: l10n.settingsExportExcel,
            icon: AppIcons.download,
            loading: _busy,
            onPressed: selected.isEmpty ? null : () => _exportExcel(selected),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: selected.isEmpty ? null : () => _copyCsv(selected),
              child: Text(
                l10n.settingsExportCsv,
                style: AppTypography.body(
                  size: 13.5,
                  color: context.palette.ink3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAnchor() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDatePickerMode: _range == _ExportRange.year
          ? DatePickerMode.year
          : DatePickerMode.day,
    );
    if (date != null && mounted) setState(() => _anchor = date);
  }

  Map<String, CategoryRow> get _categories => {
        for (final c
            in ref.read(categoriesProvider).value ?? const <CategoryRow>[])
          c.id: c,
      };

  Future<void> _exportExcel(List<TransactionRow> txns) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final categories = _categories;
      final book = xl.Excel.createExcel();
      final sheet = book['MoneyBun'];
      book.setDefaultSheet('MoneyBun');
      book.delete('Sheet1');

      sheet.appendRow([
        xl.TextCellValue('date'),
        xl.TextCellValue('type'),
        xl.TextCellValue('amount'),
        xl.TextCellValue('category'),
        xl.TextCellValue('note'),
      ]);
      for (final t in txns) {
        final date = AppDate.fromMillis(t.occurredAt);
        sheet.appendRow([
          xl.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(date)),
          xl.TextCellValue(t.type.name),
          xl.DoubleCellValue(t.amountCents / 100),
          xl.TextCellValue(
            t.categoryId == null ? '' : (categories[t.categoryId]?.name ?? ''),
          ),
          xl.TextCellValue(t.note ?? ''),
        ]);
      }

      final bytes = book.encode();
      if (bytes == null) throw StateError('encode failed');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/moneybun_$_fileSuffix.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      // Hand the file to the system share sheet so the user can save it to
      // Files, send it over Line, attach it to email, ...
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.'
                'spreadsheetml.sheet',
          ),
        ],
        subject: 'MoneyBun export',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsExportExcelDone)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsExportFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCsv(List<TransactionRow> txns) async {
    final l10n = AppLocalizations.of(context);
    final categories = _categories;
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    final buffer = StringBuffer('date,type,amount,category,note\n');
    for (final t in txns) {
      final date = AppDate.fromMillis(t.occurredAt).toIso8601String();
      final amount = (t.amountCents / 100).toStringAsFixed(2);
      final category =
          t.categoryId == null ? '' : (categories[t.categoryId]?.name ?? '');
      buffer.writeln(
        '$date,${t.type.name},$amount,'
        '${cell(category)},${cell(t.note ?? '')}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsExportCopiedClipboard)),
    );
  }
}
