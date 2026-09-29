import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/pump_app.dart';

const _wide = Size(1280, 820);

Future<void> _mac(AppDatabase db, TaskList _) =>
    KvStore(db).set(KvKeys.appStyle, AppStyle.macos.name);

void main() {
  appTest('a Mac window picks a day in a popover, at a click', (tester) async {
    await pumpApp(tester, size: _wide, seed: _mac);
    await tester.tap(find.byKey(const Key('quick-add-date')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('date-popover')), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    // Taken at the click: no OK to press, and the popover is gone.
    expect(find.byKey(const Key('date-popover')), findsNothing);
    expect(find.textContaining('15'), findsWidgets);
  });

  appTest('a phone keeps the date dialog', (tester) async {
    await pumpApp(tester, seed: _mac);
    await tester.tap(find.byKey(const Key('quick-add-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  appTest('a Mac window drops a sheet from its top', (tester) async {
    await pumpApp(
      tester,
      size: _wide,
      initialLocation: Routes.lists,
      seed: _mac,
    );
    await tester.tap(find.byKey(const Key('new-list')).first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    final name = find.text('New list').last;
    expect(tester.getTopLeft(name).dy, lessThan(100));
  });

  appTest('Mac Settings groups its rows and has a sidebar', (tester) async {
    await pumpApp(
      tester,
      size: _wide,
      initialLocation: Routes.settings,
      seed: _mac,
    );
    expect(find.byKey(const Key('settings-sidebar')), findsOneWidget);
    expect(find.byType(SettingsGroup), findsWidgets);
    // A section in the sidebar brings its part of the form into view.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-sidebar')),
        matching: find.text('About'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('About').hitTestable(), findsWidgets);
  });
}
