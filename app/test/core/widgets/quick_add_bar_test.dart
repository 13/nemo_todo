import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('the chips set priority, list and date, and reset after adding', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        await ListsRepository(
          db,
          testClock('seed'),
          sequentialIds('w'),
        ).create(name: 'Work', color: 2, icon: 'work');
      },
    );

    await tester.tap(find.byKey(const Key('quick-add-priority')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick-add-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick-add-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await quickAdd(tester, 'Write the report');

    final task = (await app.db.select(app.db.tasks).get()).single;
    expect(task.priority, 3);
    expect(task.listId, 'w1');
    expect(task.dueAt, dayStartMs(DateTime(2026, 9, 20)));

    // The date and priority go back to the screen's defaults, so the next
    // task does not inherit them by accident; the list stays chosen.
    final priority = tester.widget<Chip>(
      find.byKey(const Key('quick-add-priority')),
    );
    expect((priority.label as Text).data, 'Priority');
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-add-date')),
        matching: find.text('Today'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('quick-add-list')),
        matching: find.text('Work'),
      ),
      findsOneWidget,
    );
  });

  appTest('a blank title adds nothing', (tester) async {
    final app = await pumpApp(tester);
    await quickAdd(tester, '   ');
    expect(await app.db.select(app.db.tasks).get(), isEmpty);
  });
}
