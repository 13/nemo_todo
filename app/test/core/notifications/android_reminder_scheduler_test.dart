import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo_core/nemo_core.dart';

class FakeApi implements NotificationsApi {
  final Map<int, ({String title, String body, int at})> scheduled = {};
  final List<int> cancelled = [];
  bool initialized = false;
  bool permission = true;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
  }) async => scheduled[id] = (title: title, body: body, at: epochMs);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

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

  test('init and permission delegate to the api', () async {
    await scheduler.init();
    expect(api.initialized, isTrue);
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
}
