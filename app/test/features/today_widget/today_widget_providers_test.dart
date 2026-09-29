import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';
import 'package:nemo/features/today_widget/today_widget_providers.dart';
import 'package:nemo/features/today_widget/today_widget_tick.dart';
import 'package:nemo/features/today_widget/today_widget_updater.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_widget_bridge.dart';
import '../../support/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Two connections to one file is the point: the widget's and the app's.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late File file;
  late AppDatabase db;
  late ProviderContainer container;
  late FakeWidgetBridge bridge;
  late StreamController<String> ticks;
  late String inbox;

  // As in the daily list's test: a debounce long enough for a few writes
  // in a row to land inside it.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('nemo_widget_sync');
    file = File('${dir.path}/nemo.sqlite');
    db = AppDatabase(NativeDatabase(file));
    inbox = (await ListsRepository(
      db,
      testClock(),
      sequentialIds('l'),
    ).ensureInbox()).id;
    final boot = await AppBootstrap.load(db);
    bridge = FakeWidgetBridge();
    ticks = StreamController<String>.broadcast();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        todayWidgetBridgeProvider.overrideWithValue(bridge),
        todayWidgetTicksProvider.overrideWithValue(ticks.stream),
        todayWidgetDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 50),
        ),
      ],
    )..read(todayWidgetSyncProvider);
    await settle();
  });

  tearDown(() async {
    container.dispose();
    await ticks.close();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('hands the widget its tasks and look at start', () {
    expect(bridge.savesOf(WidgetKeys.tasks), 1);
    expect(bridge.tasks, isEmpty);
    expect(bridge.savesOf(WidgetKeys.look), 1);
    expect(bridge.look['mode'], 'system');
  });

  test('several writes in a row are one push', () async {
    final tasks = container.read(tasksRepositoryProvider);
    for (var i = 0; i < 5; i++) {
      await tasks.create(
        listId: inbox,
        title: 'T$i',
        dueAt: testNow.millisecondsSinceEpoch,
      );
    }
    await settle();
    expect(bridge.savesOf(WidgetKeys.tasks), 2);
    expect(bridge.tasks, hasLength(5));
  });

  test("a task without a date is not the widget's business", () async {
    await container
        .read(tasksRepositoryProvider)
        .create(listId: inbox, title: 'Someday');
    await settle();
    expect(bridge.savesOf(WidgetKeys.tasks), 1);
  });

  test('changing the accent or theme mode pushes the look', () async {
    await container.read(accentControllerProvider.notifier).set(3);
    await settle();
    expect(bridge.savesOf(WidgetKeys.look), 2);
    await container
        .read(themeModeControllerProvider.notifier)
        .set(ThemeMode.dark);
    await settle();
    expect(bridge.savesOf(WidgetKeys.look), 3);
    expect(bridge.look['mode'], 'dark');
    expect(bridge.savesOf(WidgetKeys.tasks), 1);
  });

  test("a tick from the widget reaches the app's streams", () async {
    final task = await container
        .read(tasksRepositoryProvider)
        .create(
          listId: inbox,
          title: 'Milk',
          dueAt: testNow.millisecondsSinceEpoch,
        );
    final today = container.listen(todayTasksProvider, (_, _) {});
    addTearDown(today.close);
    await settle();
    expect(bridge.taskIds, [task.id]);
    expect(today.read().value!.single.done, isFalse);

    // The background tick, through a connection of its own.
    final widgetDb = AppDatabase(NativeDatabase(file));
    addTearDown(widgetDb.close);
    await tickFromWidget(
      task.id,
      db: widgetDb,
      reminders: const NoopReminderScheduler(),
      widget: TodayWidgetUpdater(FakeWidgetBridge()),
      now: () => testNow.add(const Duration(minutes: 1)),
    );
    final stamp = Hlc.parse((await widgetDb.taskById(task.id))!.updatedAt);
    await settle();
    // Unseen until the app is told.
    expect(bridge.taskIds, [task.id]);

    ticks.add(task.id);
    await settle();
    expect(bridge.taskIds, isEmpty);
    // Today, as its screen watches it, shows it done.
    expect(today.read().value!.single.done, isTrue);
    expect(
      container.read(hlcClockProvider).last.compareTo(stamp),
      greaterThan(0),
    );
  });

  test('without a widget nothing is pushed', () async {
    final none = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(await AppBootstrap.load(db)),
      ],
    );
    addTearDown(none.dispose);
    none.read(todayWidgetSyncProvider);
    await settle();
    expect(bridge.savesOf(WidgetKeys.tasks), 1);
  });
}
