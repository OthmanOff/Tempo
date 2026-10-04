import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum ReminderPreset {
  atTime(Duration.zero, 'À l’heure'),
  fiveMinutes(Duration(minutes: 5), '5 min avant'),
  tenMinutes(Duration(minutes: 10), '10 min avant'),
  thirtyMinutes(Duration(minutes: 30), '30 min avant'),
  oneHour(Duration(hours: 1), '1 h avant');

  const ReminderPreset(this.offset, this.label);

  final Duration offset;
  final String label;
}

DateTime reminderTrigger(DateTime startsAt, Duration offset) =>
    startsAt.subtract(offset);

abstract interface class NotificationService {
  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> schedule({
    required String entityId,
    required String title,
    required DateTime startsAt,
    required Duration offset,
    String? body,
  });

  Future<void> cancel(String entityId, Duration offset);
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService(FlutterLocalNotificationsPlugin());
});

class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> schedule({
    required String entityId,
    required String title,
    required DateTime startsAt,
    required Duration offset,
    String? body,
  }) async {
    await initialize();
    final trigger = reminderTrigger(startsAt, offset);
    if (!trigger.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: notificationId(entityId, offset),
      title: title,
      body: body ?? 'Prévu à ${_time(startsAt)}',
      scheduledDate: tz.TZDateTime.from(trigger, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda_reminders',
          'Rappels',
          channelDescription: 'Rappels des tâches et événements planifiés',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: entityId,
    );
  }

  @override
  Future<void> cancel(String entityId, Duration offset) =>
      _plugin.cancel(id: notificationId(entityId, offset));
}

int notificationId(String entityId, Duration offset) {
  var hash = 0x811c9dc5;
  for (final unit in '$entityId:${offset.inMinutes}'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
