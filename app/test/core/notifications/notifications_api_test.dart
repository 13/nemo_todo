import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/notifications_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'requestNotificationsPermission' => true,
            'getNotificationAppLaunchDetails' => null,
            _ => null,
          };
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  LocalNotificationsApi api() =>
      LocalNotificationsApi(FlutterLocalNotificationsPlugin());

  test('initializes the plugin', () async {
    await api().initialize();
    expect(calls.map((c) => c.method), contains('initialize'));
  });

  test('schedules a reminder with its id, text and channel', () async {
    final notifications = api();
    await notifications.initialize();
    await notifications.scheduleAt(
      id: 7,
      title: 'Call the plumber',
      body: 'Due now',
      // flutter_local_notifications rejects a scheduled date that isn't in
      // the future, so this is a fixed instant well past this suite's life.
      epochMs: DateTime.utc(2099, 9, 7, 15).millisecondsSinceEpoch,
      channelName: 'Reminders',
      channelDescription: 'Notifications when a task is due',
    );

    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
            as Map<Object?, Object?>;
    expect(args['id'], 7);
    expect(args['title'], 'Call the plumber');
    expect(args['body'], 'Due now');
    final specifics = args['platformSpecifics']! as Map<Object?, Object?>;
    expect(specifics['channelId'], 'reminders');
    expect(specifics['channelName'], 'Reminders');
  });

  test('schedules on a given channel with inbox lines and a payload', () async {
    final notifications = api();
    await notifications.initialize();
    await notifications.scheduleAt(
      id: -1,
      title: '3 tasks today',
      body: 'Dentist, Milk, Taxes',
      epochMs: DateTime.utc(2099, 9, 7, 6).millisecondsSinceEpoch,
      channelName: 'Daily list',
      channelDescription: 'desc',
      channelId: 'daily_list',
      lines: ['Dentist', 'Milk', 'Taxes'],
      payload: '/today',
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
            as Map<Object?, Object?>;
    expect(args['id'], -1);
    expect(args['payload'], '/today');
    final specifics = args['platformSpecifics']! as Map<Object?, Object?>;
    expect(specifics['channelId'], 'daily_list');
    final style = specifics['styleInformation']! as Map<Object?, Object?>;
    expect(style['lines'], ['Dentist', 'Milk', 'Taxes']);
  });

  test('no launch payload when the app was not opened from one', () async {
    expect(await api().launchPayload(), isNull);
  });

  test('cancels a reminder by id', () async {
    await api().cancel(7);
    final args =
        calls.singleWhere((c) => c.method == 'cancel').arguments
            as Map<Object?, Object?>;
    expect(args['id'], 7);
  });

  test('asks Android for the permission', () async {
    expect(await api().requestPermission(), isTrue);
    expect(
      calls.map((c) => c.method),
      contains('requestNotificationsPermission'),
    );
  });
}
