@Tags(['design'])
library;

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
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
  // These render for a person to look at; without --update-goldens there
  // is nothing stored to compare against, so a plain `flutter test` would
  // only fail them. Rendering is what the flag asks for.
  if (!autoUpdateGoldenFiles) {
    test('renders only with --update-goldens', () {}, skip: true);
    return;
  }
  setUpAll(() async {
    await _loadFont('Manrope', [
      'assets/fonts/Manrope-Regular.ttf',
      'assets/fonts/Manrope-Medium.ttf',
      'assets/fonts/Manrope-SemiBold.ttf',
      'assets/fonts/Manrope-Bold.ttf',
    ]);
    await _loadFont('Inter', [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]);
    // The Material style's type: Android's system Roboto, which the web
    // bundles as RobotoWeb; tests run as Android.
    await _loadFont('Roboto', [
      'assets/fonts/RobotoWeb-Regular.ttf',
      'assets/fonts/RobotoWeb-Medium.ttf',
      'assets/fonts/RobotoWeb-Bold.ttf',
    ]);
    // The macOS style's icons.
    await _loadFont('PhosphorRegular', ['assets/fonts/PhosphorRegular.ttf']);
    await _loadFont('PhosphorFill', ['assets/fonts/PhosphorFill.ttf']);
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
    AppStyle style = AppStyle.nemo,
    // Opens something over the screen -- a sheet, a dialog -- before the
    // picture is taken.
    Future<void> Function(WidgetTester tester)? then,
  }) async {
    await pumpApp(
      tester,
      initialLocation: location,
      size: size,
      seed: (db, inbox) async {
        if (dark) await KvStore(db).set(KvKeys.themeMode, 'dark');
        await KvStore(db).set(KvKeys.appStyle, style.name);
        await seed(db, inbox);
      },
    );
    if (then != null) {
      await then(tester);
      await tester.pumpAndSettle();
    }
    // Tests draw a shadow as a solid outline, so that pictures compare
    // stably; these are for looking at, so they draw the real thing.
    debugDisableShadows = false;
    try {
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          style == AppStyle.nemo
              ? '../../build/screens/$name.png'
              : '../../build/screens/${style.name}/$name.png',
        ),
      );
    } finally {
      // Reset before the test ends: the framework checks it has been.
      debugDisableShadows = true;
    }
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
    'achievements',
    (t) => shoot(t, 'achievements', location: Routes.achievements),
  );
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

  // The other styles, under build/screens/<style>/.
  for (final style in [AppStyle.macos, AppStyle.material]) {
    for (final dark in [false, true]) {
      final suffix = dark ? '_dark' : '';
      appTest(
        '${style.name}$suffix today',
        (t) => shoot(
          t,
          'today$suffix',
          location: Routes.today,
          dark: dark,
          style: style,
        ),
      );
      appTest(
        '${style.name}$suffix lists',
        (t) => shoot(
          t,
          'lists$suffix',
          location: Routes.lists,
          dark: dark,
          style: style,
        ),
      );
      appTest(
        '${style.name}$suffix task detail',
        (t) => shoot(
          t,
          'task_detail$suffix',
          location: Routes.task('task2'),
          dark: dark,
          style: style,
        ),
      );
      appTest(
        '${style.name}$suffix settings',
        (t) => shoot(
          t,
          'settings$suffix',
          location: Routes.settings,
          dark: dark,
          style: style,
        ),
      );
      for (final (name, location) in [
        ('upcoming', Routes.upcoming),
        ('notes', Routes.notes),
        ('search', Routes.search),
        ('achievements', Routes.achievements),
      ]) {
        appTest(
          '${style.name}$suffix $name',
          (t) => shoot(
            t,
            '$name$suffix',
            location: location,
            dark: dark,
            style: style,
          ),
        );
      }
      appTest(
        '${style.name}$suffix new list sheet',
        (t) => shoot(
          t,
          'list_sheet$suffix',
          location: Routes.lists,
          dark: dark,
          style: style,
          then: (t) => t.tap(find.byKey(const Key('new-list'))),
        ),
      );
      appTest(
        '${style.name}$suffix delete dialog',
        (t) => shoot(
          t,
          'delete_dialog$suffix',
          location: Routes.lists,
          dark: dark,
          style: style,
          then: (t) async {
            await t.tap(find.text('Work'), buttons: kSecondaryButton);
            await t.pumpAndSettle();
            await t.tap(find.text('Delete'));
          },
        ),
      );
      appTest(
        '${style.name}$suffix date picker',
        (t) => shoot(
          t,
          'date_picker$suffix',
          location: Routes.today,
          dark: dark,
          style: style,
          then: (t) => _openDate(t, style),
        ),
      );
      appTest(
        '${style.name}$suffix shortcuts',
        (t) => shoot(
          t,
          'shortcuts$suffix',
          location: Routes.today,
          size: const Size(1280, 820),
          dark: dark,
          style: style,
          then: (t) async {
            await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
            await t.sendKeyEvent(LogicalKeyboardKey.slash);
            await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          },
        ),
      );
      for (final (name, location, open)
          in <(String, String, Future<void> Function(WidgetTester)?)>[
            ('settings_wide', Routes.settings, null),
            ('date_wide', Routes.today, (t) => _openDate(t, style)),
            (
              'sheet_wide',
              Routes.lists,
              (t) => t.tap(find.byKey(const Key('new-list')).first),
            ),
            (
              'menu_wide',
              Routes.today,
              (t) => t.tap(
                find.text('Call the plumber back'),
                buttons: kSecondaryButton,
              ),
            ),
          ]) {
        appTest(
          '${style.name}$suffix $name',
          (t) => shoot(
            t,
            '$name$suffix',
            location: location,
            size: const Size(1280, 820),
            dark: dark,
            style: style,
            then: open,
          ),
        );
      }
      appTest(
        '${style.name}$suffix wide, a list',
        (t) => shoot(
          t,
          'wide_list$suffix',
          location: Routes.list('list1'),
          size: const Size(1280, 820),
          dark: dark,
          style: style,
        ),
      );
      appTest(
        '${style.name}$suffix wide, a task open',
        (t) => shoot(
          t,
          'wide_selected$suffix',
          location: Routes.today,
          size: const Size(1280, 820),
          dark: dark,
          style: style,
          then: (t) => t.tap(find.text('Send the quarterly report')),
        ),
      );
      appTest(
        '${style.name}$suffix wide',
        (t) => shoot(
          t,
          'wide$suffix',
          location: Routes.today,
          size: const Size(1280, 820),
          dark: dark,
          style: style,
        ),
      );
    }
  }
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

/// Opens quick add's date: from the bar, or in the Material style from the
/// sheet its New task button brings up -- on a wide window, the rail's.
Future<void> _openDate(WidgetTester tester, AppStyle style) async {
  if (style == AppStyle.material) {
    final rail = find.byKey(const Key('rail-new-task'));
    await tester.tap(
      rail.evaluate().isNotEmpty ? rail : find.byKey(const Key('new-task')),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('quick-add-date')));
}
