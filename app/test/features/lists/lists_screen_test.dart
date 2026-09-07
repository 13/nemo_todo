import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';

void main() {
  appTest('shows the inbox, creates, opens and deletes a list', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.lists);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('No open tasks'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('list-name')), 'Groceries');
    await tester.tap(find.byKey(const Key('list-color-3')));
    await tester.tap(find.byKey(const Key('list-icon-cart')));
    await tester.tap(find.byKey(const Key('list-save')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    final list = (await app.db.select(app.db.lists).get()).firstWhere(
      (l) => !l.isInbox,
    );
    expect(list.color, 3);
    expect(list.icon, 'cart');

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();
    expect(find.text('No tasks yet. Add one below.'), findsOneWidget);
    await quickAdd(tester, 'Milk');
    await quickAdd(tester, 'Eggs');
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.byKey(const Key('list-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete "Groceries"'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.text('List deleted'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);
    expect(find.text('2 open tasks'), findsNothing);
  });

  appTest('long-press opens the menu with edit', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.lists);
    await tester.tap(find.byKey(const Key('new-list')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('list-name')), 'Work');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('list-name')), 'Job');
    await tester.tap(find.byKey(const Key('list-save')));
    await tester.pumpAndSettle();
    expect(find.text('Job'), findsOneWidget);
    expect(
      (await app.db.select(app.db.lists).get()).where((l) => l.name == 'Job'),
      hasLength(1),
    );
  });
}
