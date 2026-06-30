import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/date_period.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/segmented_control.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Bottom-sheet period picker. Top toggle switches รายเดือน / รายสัปดาห์;
/// monthly shows a 12-month grid with a year stepper, weekly shows the weeks of
/// the navigated month. Picking a value updates [selectedPeriodProvider] and
/// closes the sheet.
class PeriodPickerSheet extends ConsumerStatefulWidget {
  const PeriodPickerSheet({super.key});

  @override
  ConsumerState<PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends ConsumerState<PeriodPickerSheet> {
  late PeriodMode _mode;
  late int _navYear; // month grid: year being browsed
  late DateTime _navMonth; // week list: month being browsed (start-of-month)
  late int _navYearBlock; // year grid: first year of the 12-year block

  @override
  void initState() {
    super.initState();
    final period = ref.read(selectedPeriodProvider);
    _mode = period.mode;
    _navYear = period.anchor.year;
    _navMonth = period.monthAnchor;
    _navYearBlock = period.anchor.year - (period.anchor.year % 12);
  }

  /// Jump back to the current month and close — always "this month", whatever
  /// the active mode.
  void _jumpToThisMonth() {
    ref.read(selectedPeriodProvider.notifier).setMonth(DateTime.now());
    Navigator.of(context).maybePop();
  }

  void _pickMonth(DateTime month) {
    ref.read(selectedPeriodProvider.notifier).setMonth(month);
    Navigator.of(context).maybePop();
  }

  void _pickWeek(DateTime weekStart) {
    ref.read(selectedPeriodProvider.notifier).setWeek(weekStart);
    Navigator.of(context).maybePop();
  }

  void _pickYear(int year) {
    ref.read(selectedPeriodProvider.notifier).setYear(DateTime(year));
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider).languageCode;
    return SheetScaffold(
      title: l10n.statsSelectPeriod,
      // Size to content; the body is locked to the month/year grid height so the
      // three modes match in height and the week list scrolls within it.
      sizeToContent: true,
      maxHeightFactor: 0.9,
      action: _TodayButton(onTap: _jumpToThisMonth),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedControl<PeriodMode>(
              segments: [
                Segment(value: PeriodMode.year, label: l10n.statsYearly),
                Segment(value: PeriodMode.month, label: l10n.statsMonthly),
                Segment(value: PeriodMode.week, label: l10n.statsWeekly),
              ],
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Height the 3×4 month/year grid needs (tiles are 3-up with a
                // 2.1 aspect ratio + 10px gaps), plus its ‹ stepper › row.
                final tileW = (constraints.maxWidth - 20) / 3;
                final gridH = 4 * (tileW / 2.1) + 30;
                final bodyH = 48 + gridH; // stepper (36) + 12 gap + grid
                return SizedBox(height: bodyH, child: _buildBody(locale));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String locale) {
    switch (_mode) {
      case PeriodMode.month:
        return _MonthGrid(
          year: _navYear,
          locale: locale,
          onStepYear: (d) => setState(() => _navYear += d),
          onPick: _pickMonth,
        );
      case PeriodMode.week:
        return _WeekList(
          navMonth: _navMonth,
          locale: locale,
          onStepMonth: (d) =>
              setState(() => _navMonth = AppDate.addMonths(_navMonth, d)),
          onPick: _pickWeek,
        );
      case PeriodMode.year:
        return _YearGrid(
          blockStart: _navYearBlock,
          locale: locale,
          onStepBlock: (d) => setState(() => _navYearBlock += d * 12),
          onPick: _pickYear,
        );
    }
  }
}

/// ‹ year › stepper above a 3×4 grid of month buttons.
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({
    required this.year,
    required this.locale,
    required this.onStepYear,
    required this.onPick,
  });

  final int year;
  final String locale;
  final void Function(int delta) onStepYear;
  final void Function(DateTime month) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final isThai = locale.startsWith('th');
    final displayYear = isThai ? year + AppDate.buddhistOffset : year;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Stepper(
            label: '$displayYear',
            onPrev: () => onStepYear(-1),
            onNext: () => onStepYear(1),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (var m = 1; m <= 12; m++)
                _PickTile(
                  label: AppDate.formatMonthShort(
                    DateTime(year, m),
                    locale: locale,
                  ),
                  selected: period.monthAnchor.year == year &&
                      period.monthAnchor.month == m,
                  onTap: () => onPick(DateTime(year, m)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ‹ month year › stepper above the list of weeks overlapping that month.
class _WeekList extends ConsumerStatefulWidget {
  const _WeekList({
    required this.navMonth,
    required this.locale,
    required this.onStepMonth,
    required this.onPick,
  });

  final DateTime navMonth;
  final String locale;
  final void Function(int delta) onStepMonth;
  final void Function(DateTime weekStart) onPick;

  @override
  ConsumerState<_WeekList> createState() => _WeekListState();
}

class _WeekListState extends ConsumerState<_WeekList> {
  // Tagged onto the highlighted (current/selected) week tile so we can bring it
  // into view as soon as the week list is laid out.
  final _selectedKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_WeekList old) {
    super.didUpdateWidget(old);
    // Stepping to another month rebuilds the same list — re-centre on the
    // highlighted week when it falls in the newly shown month.
    if (old.navMonth != widget.navMonth) _revealSelected();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After layout, centre the highlighted week so it's visible the instant the
  /// week list opens; if none of the shown weeks is highlighted, reset to top.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _selectedKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else if (_scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final period = ref.watch(selectedPeriodProvider);
    final monthEnd = AppDate.endOfMonth(widget.navMonth);
    // Every week (Sunday start) that overlaps the navigated month.
    final weeks = <DateTime>[];
    var w = AppDate.startOfWeek(widget.navMonth);
    while (!w.isAfter(monthEnd)) {
      weeks.add(w);
      w = AppDate.addWeeks(w, 1);
    }
    final selectedStart = AppDate.startOfWeek(
      period.isWeek ? period.anchor : DateTime.now(),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Stepper(
          label: AppDate.formatMonth(widget.navMonth, locale: widget.locale),
          onPrev: () => widget.onStepMonth(-1),
          onNext: () => widget.onStepMonth(1),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: ListView.separated(
            controller: _scroll,
            shrinkWrap: true,
            itemCount: weeks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final selected = selectedStart == weeks[i];
              return _PickTile(
                key: selected ? _selectedKey : null,
                label: l10n.statsWeekN(i + 1),
                subtitle: AppDate.formatWeekRange(
                  weeks[i],
                  locale: widget.locale,
                ),
                selected: selected,
                onTap: () => widget.onPick(weeks[i]),
                alignStart: true,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// ‹ year-block › stepper above a 3×4 grid of years.
class _YearGrid extends ConsumerWidget {
  const _YearGrid({
    required this.blockStart,
    required this.locale,
    required this.onStepBlock,
    required this.onPick,
  });

  final int blockStart;
  final String locale;
  final void Function(int delta) onStepBlock;
  final void Function(int year) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final isThai = locale.startsWith('th');
    final offset = isThai ? AppDate.buddhistOffset : 0;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Stepper(
            label: '${blockStart + offset}–${blockStart + 11 + offset}',
            onPrev: () => onStepBlock(-1),
            onNext: () => onStepBlock(1),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (var y = blockStart; y < blockStart + 12; y++)
                _PickTile(
                  label: '${y + offset}',
                  selected: period.anchor.year == y,
                  onTap: () => onPick(y),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RoundIcon(icon: AppIcons.chevronLeft, onTap: onPrev),
        Text(
          label,
          style: AppTypography.heading(size: 16, weight: FontWeight.w600),
        ),
        _RoundIcon(icon: AppIcons.chevronRight, onTap: onNext),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.line),
        ),
        child: Icon(icon, size: 18, color: context.palette.ink2),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.alignStart = false,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.reverse : context.palette.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.terra : context.palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.terra : context.palette.line,
          ),
        ),
        alignment: alignStart ? Alignment.centerLeft : Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading(
                size: 14,
                weight: FontWeight.w500,
                color: fg,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTypography.body(
                  size: 12,
                  color: selected
                      ? AppColors.reverse.withValues(alpha: 0.85)
                      : context.palette.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "วันนี้" shortcut shown in the sheet header — jumps back to the current
/// month / week.
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: context.palette.terraWash,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          l10n.statsThisMonth,
          style: AppTypography.heading(
            size: 13,
            weight: FontWeight.w500,
            color: context.palette.terraFg,
          ),
        ),
      ),
    );
  }
}
