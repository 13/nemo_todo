@Tags(['design'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/pump_app.dart';
import '../support/test_db.dart';

/// Renders each screen to `build/screens/*.png` so the design can be looked
/// at without a device:
///
///   flutter test test/design --update-goldens
///
/// The images are build output, not checked-in golden assertions: they are
/// there to be reviewed, and a stray pixel should not fail the build.
void main() {
  setUpAll(() async {
    await _loadFont('Manrope', [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
    ]);
    final icons = File(
      '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/'
      'material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(icons.readAsBytesSync().buffer.asByteData()));
      await loader.load();
    }
  });

  Future<void> seed(AppDatabase db, TaskList inbox) async {
    final lists = ListsRepository(db, testClock('a'), sequentialIds('list'));
    final work = await lists.create(name: 'Work', color: 1, icon: 'work');
    await lists.create(name: 'Groceries', color: 5, icon: 'cart');
    final tasks = TasksRepository(
      db,
      testClock('b'),
      sequentialIds('task'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    final subtasks = SubtasksRepository(db, testClock('c'), sequentialIds('s'));
    await tasks.create(
      listId: work.id,
      title: 'Send the quarterly report',
      dueAt: dayStartMsFrom(testNow, -1),
      priority: 3,
      tags: ['office'],
    );
    final call = await tasks.create(
      listId: work.id,
      title: 'Call the plumber back',
      dueAt: composeDue(testNow, hour: 15),
      dueHasTime: true,
      priority: 2,
      notes: 'Ask about the leaking valve under the sink.',
      tags: ['home'],
    );
    await subtasks.add(call.id, 'Find the invoice');
    await subtasks.add(call.id, 'Ask about the guarantee');
    await tasks.create(
      listId: inbox.id,
      title: 'Book flights for the trip',
      dueAt: dayStartMsFrom(testNow, 2),
      priority: 1,
    );
    final done = await tasks.create(
      listId: inbox.id,
      title: 'Water the plants',
    );
    await tasks.setDone(done.id, done: true);
  }

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required String location,
    Size size = const Size(400, 820),
    bool dark = false,
  }) async {
    await pumpApp(
      tester,
      initialLocation: location,
      size: size,
      seed: (db, inbox) async {
        if (dark) await KvStore(db).set(KvKeys.themeMode, 'dark');
        await seed(db, inbox);
      },
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/screens/$name.png'),
    );
  }

  appTest('today', (t) => shoot(t, 'today', location: Routes.today));
  appTest('upcoming', (t) => shoot(t, 'upcoming', location: Routes.upcoming));
  appTest('lists', (t) => shoot(t, 'lists', location: Routes.lists));
  appTest(
    'task detail',
    (t) => shoot(t, 'task_detail', location: Routes.task('task2')),
  );
  appTest('settings', (t) => shoot(t, 'settings', location: Routes.settings));
  appTest(
    'today in the dark',
    (t) => shoot(t, 'today_dark', location: Routes.today, dark: true),
  );
  appTest(
    'task detail in the dark',
    (t) => shoot(
      t,
      'task_detail_dark',
      location: Routes.task('task2'),
      dark: true,
    ),
  );
  appTest(
    'wide',
    (t) =>
        shoot(t, 'wide', location: Routes.today, size: const Size(1280, 820)),
  );
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
  }
  await loader.load();
}
