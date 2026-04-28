import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'vird_daily';
  static const _notifId = 0;
  static const _keyEnabled = 'notif_enabled';
  static const _keyHour = 'notif_hour';
  static const _keyMinute = 'notif_minute';

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  static Future<TimeOfDay?> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_keyHour);
    if (hour == null) return null;
    return TimeOfDay(hour: hour, minute: prefs.getInt(_keyMinute) ?? 0);
  }

  static Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> scheduleDaily(int hour, int minute) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
    await _schedule(hour, minute);
  }

  static Future<void> cancel() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await _plugin.cancel(_notifId);
  }

  /// Bugün log kaydedildiğinde çağrılır — bugünkü bildirimi iptal eder,
  /// yarından itibaren tekrar başlatır (o gün okumadı ise gitsin mantığı).
  static Future<void> cancelForToday() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (!enabled) return;
    final hour = prefs.getInt(_keyHour);
    if (hour == null) return;
    final minute = prefs.getInt(_keyMinute) ?? 0;
    await _schedule(hour, minute, fromTomorrow: true);
  }

  static Future<void> _schedule(int hour, int minute, {bool fromTomorrow = false}) async {
    await _plugin.cancel(_notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (fromTomorrow || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      'Bugün okudun mu? 📖',
      'Günlük okuma hedefinize ulaşmak için şimdi başlayın.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Günlük Hatırlatıcı',
          channelDescription: 'Günlük Kuran okuma hatırlatması',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
