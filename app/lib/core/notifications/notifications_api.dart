import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The slice of `flutter_local_notifications` the app uses, behind an
/// interface so the scheduler can be tested without a device.
abstract interface class NotificationsApi {
  /// Sets the plugin up once per process. [onTap] receives the payload of a
  /// notification tapped while the app is running.
  Future<void> initialize({void Function(String? payload)? onTap});
  Future<bool> requestPermission();
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    // Shown one per line when the notification is expanded.
    List<String>? lines,
    String? payload,
  });
  Future<void> cancel(int id);

  /// The payload of the notification whose tap started the app, if one did.
  Future<String?> launchPayload();
}

class LocalNotificationsApi implements NotificationsApi {
  LocalNotificationsApi([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // The status bar draws this as a silhouette from its alpha channel,
        // so it has to be the bare mark. The launcher icon would arrive as
        // a filled white square.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: onTap == null
          ? null
          : (response) => onTap(response.payload),
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
    String channelId = 'reminders',
    List<String>? lines,
    String? payload,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    payload: payload,
    // An absolute instant; the zone only matters for repeating schedules.
    scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, epochMs),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: lines == null ? null : InboxStyleInformation(lines),
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}
