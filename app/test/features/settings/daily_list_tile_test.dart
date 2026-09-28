import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';

class PermissionScheduler implements ReminderScheduler {
  PermissionScheduler({required this.granted});
  final bool granted;

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> sync(Task task) async {}

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  List<Object> android({bool granted = true}) => [
    remindersSupportedProvider.overrideWithValue(true),
    reminderSchedulerProvider.overrideWithValue(
      PermissionScheduler(granted: granted),
    ),
  ];

  appTest('hidden where reminders are unavailable', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: [remindersSupportedProvider.overrideWithValue(false)],
    );
    expect(find.byKey(const Key('daily-list-switch')), findsNothing);
  });

  appTest('starts off at 08:00 and persists the switch', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
    );
    final finder = find.byKey(const Key('daily-list-switch'));
    await scrollIntoView(tester, finder);
    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyList), 'true');
    expect(tester.widget<SwitchListTile>(finder).value, isTrue);
  });

  appTest('refused permission leaves it off', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(granted: false),
    );
    final finder = find.byKey(const Key('daily-list-switch'));
    await scrollIntoView(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyList), isNull);
    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
  });

  appTest('the time is picked and persisted', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
      seed: (db, _) => KvStore(db).set(KvKeys.dailyList, 'true'),
    );
    final tile = find.byKey(const Key('daily-list-time'));
    await scrollIntoView(tester, tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Switch the Material time picker to text entry, then type 07:30.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '7');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyListMinutes), '450');
    expect(find.text('7:30 AM'), findsOneWidget);
  });

  appTest('the time row is disabled while the list is off', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
    );
    final tile = find.byKey(const Key('daily-list-time'));
    await scrollIntoView(tester, tile);
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
  });
}
