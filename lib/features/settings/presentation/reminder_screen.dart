import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/setting_row.dart';
import '../../../core/widgets/sub_screen_scaffold.dart';
import '../../../data/notifications/reminder_service.dart';
import '../../../l10n/generated/app_localizations.dart';

/// ตั้งค่า → แจ้งเตือนให้จด: a switch to enable the daily reminder and a row
/// to pick its time. Scheduling happens immediately on every change.
class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value;
    final enabled = settings?.reminderEnabled ?? false;
    final time = parseReminderTime(settings?.reminderTime ?? '20:00');
    final l10n = AppLocalizations.of(context);

    return SubScreenScaffold(
      title: l10n.settingsReminder,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            l10n.reminderDescription,
            style: AppTypography.body(size: 13.5, color: context.palette.ink2),
          ),
          const SizedBox(height: 16),
          SettingGroup(
            children: [
              SettingRow(
                icon: AppIcons.bellRing,
                label: l10n.reminderEnable,
                showChevron: false,
                toggleValue: enabled,
                onToggle: (v) => _setEnabled(context, ref, v, time),
              ),
              if (enabled)
                SettingRow(
                  icon: AppIcons.clock,
                  label: l10n.reminderTimeLabel,
                  value: _format(time),
                  onTap: () => _pickTime(context, ref, time),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')} น.';

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
    TimeOfDay time,
  ) async {
    final repo = ref.read(settingsRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    if (!enabled) {
      await repo.setReminderEnabled(false);
      await ReminderService.instance.cancel();
      return;
    }
    // Android 13+ runtime permission — without it the schedule is silent.
    final allowed = await ReminderService.instance.requestPermission();
    if (!allowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(l10n.reminderPermissionDenied)),
          );
      }
      return;
    }
    await repo.setReminderEnabled(true);
    await ReminderService.instance.scheduleDaily(
      time,
      title: l10n.reminderNotifTitle,
      body: l10n.reminderNotifBody,
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(settingsRepositoryProvider);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    await repo.setReminderTime(hhmm);
    await ReminderService.instance.scheduleDaily(
      picked,
      title: l10n.reminderNotifTitle,
      body: l10n.reminderNotifBody,
    );
  }
}
