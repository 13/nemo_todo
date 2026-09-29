import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_notifications.dart';

void main() {
  final now = DateTime(2026, 9, 7, 10);
  late FakeApi api;
  late AndroidReminderScheduler scheduler;

  Task task({
    bool remind = true,
    bool done = false,
    int? dueAt,
    String? deletedAt,
  }) => Task(
    id: 'task-1',
    listId: 'l',
    title: 'Dentist',
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
    remind: remind,
    done: done,
    dueAt: dueAt ?? now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
    deletedAt: deletedAt,
  );

  setUp(() {
    api = FakeApi();
    scheduler = AndroidReminderScheduler(
      api,
      channelName: 'Reminders',
      channelDescription: 'desc',
      body: 'Due now',
      now: () => now,
    );
  });

  test('permission delegates to the api', () async {
    expect(await scheduler.ensurePermission(), isTrue);
    api.permission = false;
    expect(await scheduler.ensurePermission(), isFalse);
  });

  test('schedules open future reminders and cancels everything else', () async {
    final id = AndroidReminderScheduler.notificationId('task-1');
    expect(id, greaterThanOrEqualTo(0));
    await scheduler.sync(task());
    expect(api.scheduled[id]!.title, 'Dentist');
    expect(api.scheduled[id]!.body, 'Due now');
    await scheduler.sync(task(done: true));
    expect(api.scheduled, isEmpty);
    expect(api.cancelled, [id]);
    await scheduler.sync(task(remind: false));
    await scheduler.sync(task(deletedAt: 'x'));
    await scheduler.sync(task(dueAt: now.millisecondsSinceEpoch - 1));
    expect(api.cancelled, hasLength(4));
    await scheduler.cancel('task-1');
    expect(api.cancelled, hasLength(5));
  });

  test('a tap opens the task', () async {
    await scheduler.sync(task());
    final id = AndroidReminderScheduler.notificationId('task-1');
    expect(api.scheduled[id]!.payload, '/tasks/task-1');
  });

  test('a missed window keeps a just-due task scheduled', () async {
    final web = AndroidReminderScheduler(
      api,
      channelName: 'Reminders',
      channelDescription: 'desc',
      body: 'Due now',
      missedWindow: const Duration(minutes: 10),
      now: () => now,
    );
    final id = AndroidReminderScheduler.notificationId('task-1');
    final fiveAgo = now.subtract(const Duration(minutes: 5));
    await web.sync(task(dueAt: fiveAgo.millisecondsSinceEpoch));
    expect(api.scheduled[id]!.at, fiveAgo.millisecondsSinceEpoch);
    final hourAgo = now.subtract(const Duration(hours: 1));
    await web.sync(task(dueAt: hourAgo.millisecondsSinceEpoch));
    expect(api.scheduled, isEmpty);
  });
}
