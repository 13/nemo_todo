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
