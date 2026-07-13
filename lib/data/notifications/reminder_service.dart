import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the daily "อย่าลืมจด" reminder notification — fully local, no
/// server. The schedule repeats every day at the user's chosen time and is
/// re-delivered after a reboot/app update by the boot receiver declared in
/// AndroidManifest.xml.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _notificationId = 1001;
  static const _channelId = 'daily_reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Idempotent init: notification plugin + the tz database (needed to compute
  /// "next 20:00 local time" across DST-less Thailand and everywhere else).
  Future<void> _ensureInitialised() async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Unknown zone name — fall back to the tz package default (UTC). The
      // reminder still fires daily, just anchored to UTC.
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialised = true;
  }

  /// Ask for the Android 13+ notification permission. Returns whether
  /// notifications are allowed (true on older Androids).
  Future<bool> requestPermission() async {
    await _ensureInitialised();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  /// (Re)schedule the daily reminder at [time]. Replaces any previous one.
  Future<void> scheduleDaily(
    TimeOfDay time, {
    required String title,
    required String body,
  }) async {
    await _ensureInitialised();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'เตือนจดบันทึกประจำวัน',
        channelDescription: 'แจ้งเตือนให้จดรายรับรายจ่ายทุกวัน',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final first = _nextInstanceOf(time);
    try {
      await _plugin.zonedSchedule(
        _notificationId,
        title,
        body,
        first,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    } catch (_) {
      // Exact alarms not permitted on this device (Android 12+ special
      // access) — an inexact daily reminder is fine for "อย่าลืมจด".
      await _plugin.zonedSchedule(
        _notificationId,
        title,
        body,
        first,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancel() async {
    await _ensureInitialised();
    await _plugin.cancel(_notificationId);
  }

  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}

/// Parse a stored 'HH:mm' into a [TimeOfDay]; malformed values fall back to
/// 20:00 so a corrupt setting can't crash the reminder screen.
TimeOfDay parseReminderTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '');
  final m = int.tryParse(parts.length > 1 ? parts[1] : '');
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return const TimeOfDay(hour: 20, minute: 0);
  }
  return TimeOfDay(hour: h, minute: m);
}
