import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/tasks/ui/tag_screen.dart';
import 'package:nemo/router.dart';

import '../support/a11y.dart';
import '../support/pump_app.dart';

/// What a screen reader finds on a task row: one node saying the whole
/// row, with what its gestures do as actions, and the tick as a checkbox
/// of its own.
void main() {
  SemanticsFinder row(String title) =>
      find.semantics.byLabel(RegExp('^${RegExp.escape(title)}\\. '));
  SemanticsFinder check(String title) => find.semantics.byLabel('Done: $title');

  for (final style in AppStyle.values) {
    group(style.name, () {
      appTest('a row says its title, due date, priority, list and more', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpA11y(tester, style: style, location: Routes.today);

        final call = row('Call the plumber back').evaluate().single;
        expect(call.label, startsWith('Call the plumber back. Due Today, '));
        expect(
          call.label,
          endsWith(
            '. Medium priority. In Work. 0 of 2 subtasks done. Tags: home',
          ),
        );
        expect(call, isSemantics(isButton: true, hasTapAction: true));
        // Overdue is said as such.
        expect(
          row('Send the quarterly report').evaluate().single.label,
          'Send the quarterly report. Overdue, due Yesterday. '
          'High priority. In Work. Tags: office',
        );
        // The row's own texts are not read a second time.
        expect(find.semantics.byLabel('Call the plumber back'), findsNothing);
        handle.dispose();
      });

      appTest('the tick is a labelled checkbox that says its state', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final app = await pumpA11y(
          tester,
          style: style,
          location: Routes.today,
        );
        expect(
          check('Call the plumber back').evaluate().single,
          isSemantics(
            label: 'Done: Call the plumber back',
            hasCheckedState: true,
            isChecked: false,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        tester.semantics.tap(check('Call the plumber back'));
        await tester.pumpAndSettle();
        final task = await (app.db.select(
          app.db.tasks,
        )..where((t) => t.id.equals('task2'))).getSingle();
        expect(task.done, isTrue);
        handle.dispose();
      });

      appTest('what a gesture does is an action on the row', (tester) async {
        final handle = tester.ensureSemantics();
        final app = await pumpA11y(
          tester,
          style: style,
          location: Routes.today,
        );
        final node = row('Call the plumber back').evaluate().single;
        final actions = [
          for (final id in node.getSemanticsData().customSemanticsActionIds!)
            CustomSemanticsAction.getAction(id)!.label,
        ];
        expect(actions, ['Mark as done', 'Move to…', 'Delete', 'Show #home']);

        // A swipe's delete, with the gesture out of reach.
        tester.semantics.customAction(
          row('Call the plumber back'),
          const CustomSemanticsAction(label: 'Delete'),
        );
        await tester.pumpAndSettle();
        final task = await (app.db.select(
          app.db.tasks,
        )..where((t) => t.id.equals('task2'))).getSingleOrNull();
        expect(task == null || task.deletedAt != null, isTrue);

        // A tag's own tap.
        tester.semantics.customAction(
          row('Send the quarterly report'),
          const CustomSemanticsAction(label: 'Show #office'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TagScreen), findsOneWidget);
        handle.dispose();
      });

      appTest('a finished task says it is ticked', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpA11y(tester, style: style, location: Routes.list('list1'));
        // Completed tasks are folded away until their header is opened.
        final header = find.semantics.byPredicate(
          (n) => n.label == '1 completed',
        );
        expect(
          header.evaluate().single,
          isSemantics(isButton: true, hasExpandedState: true),
        );
        tester.semantics.tap(header);
        await tester.pumpAndSettle();
        expect(
          header.evaluate().single,
          isSemantics(hasExpandedState: true, isExpanded: true),
        );
        expect(
          check('Water the plants').evaluate().single,
          isSemantics(hasCheckedState: true, isChecked: true),
        );
        handle.dispose();
      });
    });
  }

  appTest("the check's target grows, but the ring stays where it was", (
    tester,
  ) async {
    await pumpA11y(tester, style: AppStyle.nemo, location: Routes.today);
    final tile = find.ancestor(
      of: find.text('Call the plumber back'),
      matching: find.byType(TaskTile),
    );
    final check = find.descendant(of: tile, matching: find.byType(DoneCheck));
    final origin = tester.getTopLeft(tile);
    expect(tester.getSize(check), const Size(48, 48));
    // The ring's centre, and the title beside it, as they were drawn when
    // the target was the ring and a third again: 8 + 20 across, 6 + 20
    // down, and the title after the 40 px target and a 4 px gap.
    expect(tester.getCenter(check) - origin, const Offset(28, 26));
    expect(
      tester.getTopLeft(find.text('Call the plumber back')).dx - origin.dx,
      52,
    );
  });

  appTest('a Mac keeps its dense check where there is a pointer', (
    tester,
  ) async {
    await pumpA11y(
      tester,
      style: AppStyle.macos,
      location: Routes.today,
      size: const Size(1280, 820),
    );
    final tile = find.ancestor(
      of: find.text('Call the plumber back'),
      matching: find.byType(TaskTile),
    );
    final check = find.descendant(of: tile, matching: find.byType(DoneCheck));
    expect(tester.getSize(check), const Size(30, 30));
  });
}
