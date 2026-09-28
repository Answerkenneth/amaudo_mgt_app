import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'notification_router.dart';

/// Thin wrapper around flutter_local_notifications. Local-only,
/// free-tier — no Cloud Functions, no server scheduling. Reminders
/// fire while the device has the app installed and notification
/// permission granted; this cannot guarantee delivery if the OS
/// force-kills the app or restricts background activity (a platform
/// limitation, not something any Firebase plan changes).
class LocalNotificationService {
  LocalNotificationService._internal();
  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      // Fires when the user taps a notification THIS plugin
      // displayed (i.e. showNow() below, used for FCM messages that
      // arrive while the app is in the foreground). The payload is
      // the JSON-encoded {type, ...data} produced by showNow, so it
      // routes through the exact same deep-link logic as every other
      // notification-tap path.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        NotificationRouter.routeFromPayload(payload);
      },
    );

    _initialized = true;
  }

  /// Deterministic integer ID from a string key, so the same logical
  /// reminder always maps to the same notification ID — scheduling
  /// again with the same key overwrites rather than duplicates it.
  int idFromKey(String key) => key.hashCode & 0x7FFFFFFF;

  Future<void> scheduleDaily({
    required String key,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    final id = idFromKey(key);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'amaudo_reminders',
          'Amaudo Reminders',
          channelDescription: 'Profile, medication, and appointment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

    Future<void> cancel(String key) async {
    await init();
    await _plugin.cancel(idFromKey(key));
  }

  /// Shows a notification immediately. Used for FCM messages that
  /// arrive while the app is in the foreground — FCM auto-displays
  /// the system tray notification when backgrounded/closed, but not
  /// while the app is open, so this fills that one gap. See
  /// FcmService.
  ///
  /// [payload] carries the JSON-encoded {type, ...data} for this
  /// notification (see NotificationRouter.encodePayload) so a tap on
  /// it deep links exactly like a tap on the system-tray/in-app
  /// version of the same notification. Omit it only for the rare
  /// notification with nothing to deep link to.
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'amaudo_reminders',
          'Amaudo Reminders',
          channelDescription: 'Profile, medication, and appointment reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
      );
  }
}