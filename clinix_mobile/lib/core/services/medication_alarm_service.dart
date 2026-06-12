import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules medication reminders as LOCAL alarm-style notifications on the
/// device. They fire at the exact dose time with sound + vibration — even if
/// the app is closed and regardless of whether the server's push pipeline is
/// up. Call [syncAlarms] whenever the active reminder list is (re)loaded.
class MedicationAlarmService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _payloadPrefix = 'medreminder';
  static bool _tzReady = false;

  static void _ensureTz() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'clinix_med_alarms',
    'Medication Alarms',
    channelDescription: 'Alarm-style reminders to take your medication',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  /// Re-syncs all daily medication alarms to match [reminders] (the list
  /// returned by `consultations/reminders/`). Cancels alarms for reminders
  /// that no longer exist.
  static Future<void> syncAlarms(List<Map<String, dynamic>> reminders) async {
    try {
      _ensureTz();

      // Ask Android 12+ for the exact-alarm capability (no-op elsewhere).
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestExactAlarmsPermission();
      } catch (_) {}

      // Drop every previously scheduled medication alarm, then re-add.
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if ((p.payload ?? '').startsWith(_payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }

      for (final r in reminders) {
        final id = r['id']?.toString() ?? '';
        final name = r['medication_name']?.toString() ?? 'your medication';
        final dosage = r['dosage']?.toString() ?? '';
        final times = (r['reminder_times'] as List?) ?? const [];
        if (id.isEmpty) continue;

        for (final t in times) {
          final parts = t.toString().split(':');
          if (parts.length < 2) continue;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null) continue;

          await _scheduleDaily(
            notifId: _notifId(id, h, m),
            hour: h,
            minute: m,
            title: 'Time for your medication',
            body: dosage.isEmpty ? 'Take $name now.' : 'Take $name ($dosage) now.',
          );
        }
      }
    } catch (e) {
      debugPrint('[MedAlarm] syncAlarms failed: $e');
    }
  }

  /// Deterministic 31-bit id per reminder+time so re-syncs overwrite instead
  /// of stacking duplicates.
  static int _notifId(String reminderId, int hour, int minute) {
    final h = reminderId.hashCode & 0x3FFFF; // 18 bits of the reminder id
    return (h << 11) | (hour << 6) | minute; // + 5 bits hour + 6 bits minute
  }

  static Future<void> _scheduleDaily({
    required int notifId,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (first.isBefore(now)) first = first.add(const Duration(days: 1));

    try {
      await _plugin.zonedSchedule(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: first,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$_payloadPrefix:/patient/medication-reminders',
      );
    } catch (e) {
      // Exact alarms can be blocked by the OS; fall back to inexact so the
      // reminder still fires (possibly a few minutes late).
      try {
        await _plugin.zonedSchedule(
          id: notifId,
          title: title,
          body: body,
          scheduledDate: first,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '$_payloadPrefix:/patient/medication-reminders',
        );
      } catch (e2) {
        debugPrint('[MedAlarm] schedule failed: $e2');
      }
    }
  }
}
