import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// A list "Errands" (`list1`) holding, in the order they were added:
/// Pay rent (high, due in two days), buy milk (none, undated), Call mum
/// (low, due tomorrow).
Future<TestApp> _pump(
  WidgetTester tester,
  AppStyle style, {
  String location = Routes.lists,
  bool editor = false,
}) => pumpApp(
  tester,
  initialLocation: location,
  seed: (db, inbox) async {
    await KvStore(db).set(KvKeys.appStyle, style.name);
    final list = await ListsRepository(
      db,
      testClock('a'),
      sequentialIds('list'),
    ).create(name: 'Errands');
    // A minute apart, so "date added" has something to sort by.
    var added = 0;
    final tasks = TasksRepository(
      db,
      testClock('b'),
      sequentialIds('task'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow.add(Duration(minutes: added++)),
    );
    final day = const Duration(days: 1).inMilliseconds;
    final now = testNow.millisecondsSinceEpoch;
    await tasks.create(
      listId: list.id,
      title: 'Pay rent',
      priority: 3,
      dueAt: now + 2 * day,
    );
    await tasks.create(listId: list.id, title: 'buy milk');
    await tasks.create(
      listId: list.id,
      title: 'Call mum',
      priority: 1,
      dueAt: now + day,
    );
    if (editor) {
      await db.setListMeta({
        list.id: const [
          ListMember(username: 'ann', role: MemberRole.owner),
          ListMember(username: 'ben', role: MemberRole.editor),
        ],
      }, 'ben');
    }
  },
);

List<String> _titles(WidgetTester tester) {
  const titles = ['Pay rent', 'buy milk', 'Call mum'];
  final found = [
    for (final t in titles)
      if (find.text(t).evaluate().isNotEmpty)
        (t, tester.getTopLeft(find.text(t)).dy),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final (t, _) in found) t];
}

Future<void> _choose(WidgetTester tester, String order) async {
  await tester.tap(find.text(order).last);
  await tester.pumpAndSettle();
}

Future<void> _openPageMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('list-menu')));
  await tester.pumpAndSettle();
}

List<String> _actions(WidgetTester tester, String title) {
  final node = find.semantics
      .byLabel(RegExp('^${RegExp.escape(title)}(\\. |\$)'))
      .evaluate()
      .single;
  return [
    for (final id
        in node.getSemanticsData().customSemanticsActionIds ?? const <int>[])
      CustomSemanticsAction.getAction(id)!.label ?? '',
  ];
}

void main() {
  for (final style in AppStyle.values) {
    group(style.name, () {
      appTest('the page menu sorts the list and the banner says so', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final app = await _pump(tester, style, location: Routes.list('list1'));
        expect(_titles(tester), ['Pay rent', 'buy milk', 'Call mum']);
        expect(find.byKey(const Key('task-order-banner')), findsNothing);
        expect(
          _actions(tester, 'buy milk'),
          containsAll(['Move up', 'Move down']),
        );
        expect(_actions(tester, 'Pay rent'), isNot(contains('Move up')));

        await _openPageMenu(tester);
        await tester.tap(find.text('Sort by'));
        await tester.pumpAndSettle();
        await _choose(tester, 'Title');

        expect(_titles(tester), ['buy milk', 'Call mum', 'Pay rent']);
        expect(find.text('Sorted by: Title'), findsOneWidget);
        expect((await app.db.listById('list1'))!.order, TaskOrder.title);
        expect(
          _actions(tester, 'Call mum'),
          isNot(anyOf(contains('Move up'), contains('Move down'))),
          reason: 'a sorted list cannot be reordered by hand',
        );

        // The banner is the way back.
        await tester.tap(find.byKey(const Key('task-order-banner')));
        await tester.pumpAndSettle();
        await _choose(tester, 'Priority');
        expect(_titles(tester), ['Pay rent', 'Call mum', 'buy milk']);

        await tester.tap(find.byKey(const Key('task-order-banner')));
        await tester.pumpAndSettle();
        await _choose(tester, 'Due date');
        expect(_titles(tester), ['Call mum', 'Pay rent', 'buy milk']);

        await tester.tap(find.byKey(const Key('task-order-banner')));
        await tester.pumpAndSettle();
        await _choose(tester, 'Manual');
        expect(_titles(tester), ['Pay rent', 'buy milk', 'Call mum']);
        expect(find.byKey(const Key('task-order-banner')), findsNothing);
        expect(_actions(tester, 'buy milk'), contains('Move up'));
        handle.dispose();
      });

      appTest("the list card's menu sorts it too", (tester) async {
        final app = await _pump(tester, style);
        final card = find.text('Errands');
        if (style == AppStyle.macos) {
          // A Mac's menu is a pop-up at the pointer.
          await tester.tap(card, buttons: kSecondaryButton);
        } else {
          await tester.longPress(card);
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sort by'));
        await tester.pumpAndSettle();
        await _choose(tester, 'Date added');

        expect((await app.db.listById('list1'))!.order, TaskOrder.added);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(_titles(tester), ['Call mum', 'buy milk', 'Pay rent']);
        expect(find.text('Sorted by: Date added'), findsOneWidget);
      });

      appTest('an editor of a shared list is not offered the choice', (
        tester,
      ) async {
        await _pump(
          tester,
          style,
          location: Routes.list('list1'),
          editor: true,
        );
        await _openPageMenu(tester);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Sort by'), findsNothing);
      });
    });
  }

  appTest('a screen reader moves a task in a hand-sorted list', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _pump(
      tester,
      AppStyle.nemo,
      location: Routes.list('list1'),
    );
    tester.semantics.customAction(
      find.semantics.byLabel(RegExp(r'^buy milk(\. |$)')),
      const CustomSemanticsAction(label: 'Move down'),
    );
    await tester.pumpAndSettle();
    expect(_titles(tester), ['Pay rent', 'Call mum', 'buy milk']);

    tester.semantics.customAction(
      find.semantics.byLabel(RegExp(r'^Call mum(\. |$)')),
      const CustomSemanticsAction(label: 'Move up'),
    );
    await tester.pumpAndSettle();
    expect(_titles(tester), ['Call mum', 'Pay rent', 'buy milk']);
    expect(await app.db.outboxCount(), greaterThan(0));
    handle.dispose();
  });
}
