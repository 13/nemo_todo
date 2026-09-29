import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/due_chip.dart';
import 'package:nemo/features/notes/ui/notes_screen.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/today_screen.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';
import 'package:nemo/utils/dates.dart';

import '../support/pump_app.dart';
import '../support/test_db.dart';

void main() {
  appTest('phone width uses a bottom bar and navigates', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing planned'), findsOneWidget);
  });

  appTest('wide width uses a rail with a settings button', (tester) async {
    await pumpApp(tester, size: const Size(900, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  appTest('a very wide window opens a task beside the list', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1400, 900),
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(
          listId: inbox.id,
          title: 'Ring the plumber',
          // Due today, so it is on the screen the app opens at.
          dueAt: composeDue(testNow, hour: 15),
        );
      },
    );

    expect(find.textContaining('Pick a task'), findsOneWidget);

    await tester.tap(find.text('Ring the plumber'));
    await tester.pumpAndSettle();

    // Beside the list, not instead of it: the rail and the list are still
    // there, and the task is now in the second pane.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.textContaining('Pick a task'), findsNothing);
    expect(find.text('Ring the plumber'), findsNWidgets(2));
    // Nothing was pushed, so there is nothing to go back from.
    expect(find.byType(BackButton), findsNothing);

    // Changing destination puts the pane away: the task belonged to Today.
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick a task'), findsOneWidget);
  });

  appTest('a narrow window still opens a task as a page', (tester) async {
    await pumpApp(
      tester,
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(
          listId: inbox.id,
          title: 'Ring the plumber',
          // Due today, so it is on the screen the app opens at.
          dueAt: composeDue(testNow, hour: 15),
        );
      },
    );
    await tester.tap(find.text('Ring the plumber'));
    await tester.pumpAndSettle();
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'a page of its own',
    );
    expect(find.byType(BackButton), findsOneWidget);
  });

  appTest('the notes route is exempt from the shell width cap', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.notes,
      size: const Size(1000, 900),
    );

    // The notes grid needs the width the shell would otherwise cap at 720.
    expect(tester.getSize(find.byType(NotesScreen)).width, greaterThan(720));

    // Another shell route still gets the usual cap.
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TodayScreen)).width, 720);
  });

  appTest('the macOS style navigates from a sidebar', (tester) async {
    await pumpApp(
      tester,
      size: const Size(1000, 800),
      seed: (db, _) => KvStore(db).set(KvKeys.appStyle, AppStyle.macos.name),
    );
    expect(find.byKey(const Key('mac-sidebar')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  appTest('outside nemo, a list keeps its colour to its icon', (tester) async {
    await pumpApp(
      tester,
      seed: (db, inbox) async {
        await KvStore(db).set(KvKeys.appStyle, AppStyle.macos.name);
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(
          listId: inbox.id,
          title: 'Ring the plumber',
          dueAt: dayStartMsFrom(testNow, -1),
        );
      },
    );
    final context = tester.element(find.text('Ring the plumber'));
    final scheme = Theme.of(context).colorScheme;
    Color? textColor(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    // The due date stays in its colour: overdue is worth reading first.
    expect(textColor('Yesterday'), context.nemoColors.overdue);
    // The list's name is secondary text; only its icon is in its colour.
    final listChip = find.ancestor(
      of: find.text('Inbox'),
      matching: find.byType(MetaChip),
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: listChip, matching: find.byType(Text)),
          )
          .style
          ?.color,
      scheme.onSurfaceVariant,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: listChip, matching: find.byType(Icon)),
          )
          .color,
      context.nemoColors.listColor(0),
    );
  });

  test('indexFor maps locations', () {
    expect(ShellScreen.indexFor('/today'), 0);
    expect(ShellScreen.indexFor('/upcoming'), 1);
    expect(ShellScreen.indexFor('/lists/abc'), 2);
    expect(ShellScreen.indexFor('/notes'), 3);
    expect(ShellScreen.indexFor('/search'), 4);
    expect(ShellScreen.indexFor('/whatever'), 0);
  });
}
