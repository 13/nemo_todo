import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/today_widget/today_widget_tick.dart';
import 'package:nemo/features/today_widget/today_widget_updater.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_widget_bridge.dart';
import '../../support/test_db.dart';

class RecordingReminders implements ReminderScheduler {
  final synced = <Task>[];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> sync(Task task) async => synced.add(task);

  @override
  Future<void> cancel(String taskId) async {}
}

class CountingDailyList implements DailyDigestScheduler {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  // Two connections to one file is the point: the widget's and the app's.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  // The app's connection and the widget's, on one file, as on a phone.
  late AppDatabase app;
  late AppDatabase widgetDb;
  late TasksRepository tasks;
  late String inbox;
  late FakeWidgetBridge bridge;
  late RecordingReminders reminders;
  late CountingDailyList dailyList;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('nemo_widget_tick');
    final file = File('${dir.path}/nemo.sqlite');
    app = AppDatabase(NativeDatabase(file));
    widgetDb = AppDatabase(NativeDatabase(file));
    final boot = await AppBootstrap.load(app);
    final clock = HlcClock(node: boot.nodeId, now: () => testNow);
    inbox = (await ListsRepository(
      app,
      clock,
      sequentialIds('l'),
    ).ensureInbox()).id;
    tasks = TasksRepository(
      app,
      clock,
      sequentialIds(),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    bridge = FakeWidgetBridge();
    reminders = RecordingReminders();
    dailyList = CountingDailyList();
  });

  tearDown(() async {
    await app.close();
    await widgetDb.close();
    dir.deleteSync(recursive: true);
  });

  Future<bool> tick(String id) => tickFromWidget(
    id,
    db: widgetDb,
    reminders: reminders,
    widget: TodayWidgetUpdater(bridge),
    dailyList: (_, _) => dailyList,
    now: () => testNow.add(const Duration(minutes: 5)),
    newId: sequentialIds('w'),
  );

  test('ticks the task off the way the app does', () async {
    final task = await tasks.create(
      listId: inbox,
      title: 'Milk',
      dueAt: testNow.millisecondsSinceEpoch,
    );
    final other = await tasks.create(
      listId: inbox,
      title: 'Bread',
      dueAt: testNow.millisecondsSinceEpoch,
    );

    expect(await tick(task.id), isTrue);

    final done = (await app.taskById(task.id))!;
    expect(done.done, isTrue);
    expect(
      done.doneAt,
      testNow.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    );
    // Stamped by this device, after everything it had stamped before.
    final boot = await AppBootstrap.load(app);
    final stamp = Hlc.parse(done.updatedAt);
    expect(stamp.node, boot.nodeId);
    expect(stamp.compareTo(Hlc.parse(task.updatedAt)), greaterThan(0));
    expect(await KvStore(app).get(KvKeys.hlcLast), done.updatedAt);
    // Waiting for the next sync.
    final outbox = await app.select(app.outbox).get();
    expect(
      outbox.where((r) => r.rowId == task.id).single.enqueuedUpdatedAt,
      done.updatedAt,
    );
    // Its reminder follows, the widget gets the rest, the daily list is
    // rebuilt.
    expect(reminders.synced.single.done, isTrue);
    expect(bridge.taskIds, [other.id]);
    expect(bridge.redraws, 1);
    expect(dailyList.refreshes, 1);
  });

  test('a repeating task comes back, and the widget shows it', () async {
    final task = await tasks.create(
      listId: inbox,
      title: 'Water plants',
      dueAt: testNow.millisecondsSinceEpoch,
      repeat: Repeats.daily,
    );

    await tick(task.id);

    final open = await tasks.watchOpenDated().first;
    expect(open.single.title, 'Water plants');
    expect(open.single.id, isNot(task.id));
    expect(open.single.dueAt, greaterThan(task.dueAt!));
    expect(bridge.taskIds, [open.single.id]);
  });

  test('a task already done or gone is left alone', () async {
    final task = await tasks.create(
      listId: inbox,
      title: 'Milk',
      dueAt: testNow.millisecondsSinceEpoch,
    );
    await tasks.setDone(task.id, done: true);
    final before = (await app.taskById(task.id))!.updatedAt;

    expect(await tick(task.id), isFalse);
    expect(await tick('nobody'), isFalse);

    expect((await app.taskById(task.id))!.updatedAt, before);
    expect(reminders.synced, isEmpty);
    expect(dailyList.refreshes, 0);
    // The widget still hears what is open, so a hidden row settles: each
    // background run starts afresh, so both redraw.
    expect(bridge.tasks, isEmpty);
    expect(bridge.redraws, 2);
  });
}
