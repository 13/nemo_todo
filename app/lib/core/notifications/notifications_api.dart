import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The slice of `flutter_local_notifications` the app uses, behind an
/// interface so the scheduler can be tested without a device.
abstract interface class NotificationsApi {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
  });
  Future<void> cancel(int id);
}

class LocalNotificationsApi implements NotificationsApi {
  LocalNotificationsApi([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // The status bar draws this as a silhouette from its alpha channel,
        // so it has to be the bare mark. The launcher icon would arrive as
        // a filled white square.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    // An absolute instant; the zone only matters for repeating schedules.
    scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, epochMs),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
