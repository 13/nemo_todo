import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import 'pump_app.dart';
import 'test_db.dart';

/// The screens an accessibility check walks, by name: every one somebody
/// spends their time on, over data that fills each of them.
final a11yScreens = <String, String>{
  'Today': Routes.today,
  'Upcoming': Routes.upcoming,
  'Lists': Routes.lists,
  'a list': Routes.list('list1'),
  'task detail': Routes.task('task2'),
  'note detail': Routes.note('note1'),
  'Settings': Routes.settings,
};

/// [location] in [style], dark or light and in the [accent] chosen in
/// Settings, over a list with tasks of every kind a row can show: overdue,
/// timed, flagged, tagged, with subtasks, done.
Future<TestApp> pumpA11y(
  WidgetTester tester, {
  required AppStyle style,
  required String location,
  bool dark = false,
  int? accent,
  Size size = const Size(400, 800),
  bool settle = true,
}) => pumpApp(
  tester,
  initialLocation: location,
  size: size,
  settle: settle,
  seed: (db, inbox) async {
    await KvStore(db).set(KvKeys.appStyle, style.name);
    await KvStore(db).set(KvKeys.themeMode, dark ? 'dark' : 'light');
    if (accent != null) await KvStore(db).set(KvKeys.accent, '$accent');
    await seedA11y(db, inbox);
  },
);

/// The rows [pumpA11y] shows: a list "Work" (`list1`) holding tasks
/// `task1` to `task4` and a note `note1`.
Future<void> seedA11y(AppDatabase db, TaskList inbox) async {
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
  final subtasks = SubtasksRepository(db, testClock('c'), sequentialIds('s'));
  await subtasks.add(call.id, 'Find the invoice');
  await subtasks.add(call.id, 'Ask about the guarantee');
  await tasks.create(
    listId: work.id,
    title: 'Book flights for the trip',
    dueAt: dayStartMsFrom(testNow, 2),
    priority: 1,
  );
  final done = await tasks.create(listId: work.id, title: 'Water the plants');
  await tasks.setDone(done.id, done: true);
  await NotesRepository(db, testClock('d'), sequentialIds('note')).create(
    listId: work.id,
    title: 'Trip ideas',
    body: '# Places\n\n- [ ] Lisbon\n- [x] Porto\n\nA **long** weekend.',
  );
}

/// [androidTapTargetGuideline] without its one exemption: Flutter's skips
/// any target touching an edge of the screen or of a scrolling list, in
/// case it is scrolled partly out of view -- which passes a full-width
/// row, or a chip in a row of them, however short. This measures every
/// target lying wholly in view, and skips only those cut off.
const fingerTapTargetGuideline = _FingerTapTargetGuideline();

class _FingerTapTargetGuideline extends AccessibilityGuideline {
  const _FingerTapTargetGuideline();

  static const _size = Size.square(kMinInteractiveDimension);

  @override
  String get description =>
      'Tappable objects in view should be at least $_size';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final view in tester.binding.renderViews) {
      final screen = Offset.zero & view.flutterView.physicalSize;
      void visit(SemanticsNode node) {
        node.visitChildren((child) {
          visit(child);
          return true;
        });
        final data = node.getSemanticsData();
        if (node.isMergedIntoParent ||
            data.flagsCollection.isHidden ||
            data.flagsCollection.isLink ||
            !(data.hasAction(ui.SemanticsAction.tap) ||
                data.hasAction(ui.SemanticsAction.longPress))) {
          return;
        }
        // The node in the screen's coordinates, and whether a scrolling
        // list it sits in may cut it off: a node reaching the end of a
        // list in the direction it scrolls can be part scrolled away.
        var rect = node.rect;
        var clipped = false;
        for (SemanticsNode? n = node; n != null; n = n.parent) {
          final transform = n.transform;
          if (transform != null) {
            rect = MatrixUtils.transformRect(transform, rect);
          }
          final parent = n.parent;
          if (parent == null || !parent.flagsCollection.hasImplicitScrolling) {
            continue;
          }
          final list = parent.getSemanticsData();
          final box = parent.rect;
          bool scrolls(ui.SemanticsAction a, ui.SemanticsAction b) =>
              list.hasAction(a) || list.hasAction(b);
          if (!_within(rect, box) ||
              scrolls(.scrollUp, .scrollDown) &&
                  (rect.top <= box.top + 0.01 ||
                      rect.bottom >= box.bottom - 0.01) ||
              scrolls(.scrollLeft, .scrollRight) &&
                  (rect.left <= box.left + 0.01 ||
                      rect.right >= box.right - 0.01)) {
            clipped = true;
          }
        }
        if (clipped || !_within(rect, screen)) return;
        final size = rect.size / view.flutterView.devicePixelRatio;
        if (size.width < _size.width - precisionErrorTolerance ||
            size.height < _size.height - precisionErrorTolerance) {
          result += Evaluation.fail(
            '$node: expected tap target size of at least $_size, '
            'but found $size',
          );
        }
      }

      visit(view.owner!.semanticsOwner!.rootSemanticsNode!);
    }
    return result;
  }

  static bool _within(Rect child, Rect parent) {
    final room = parent.inflate(0.01);
    return room.contains(child.topLeft) && room.contains(child.bottomRight);
  }
}
