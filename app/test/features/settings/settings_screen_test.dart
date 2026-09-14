import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/achievements/ui/achievements_screen.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';

void main() {
  appTest('theme choice is applied and persisted', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.themeMode), 'dark');
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });

  appTest('celebrations start on, sound off, achievements on', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings, celebrate: true);
    bool value(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key))).value;
    expect(value('celebrations-switch'), isTrue);
    expect(value('celebration-sound-switch'), isFalse);
    expect(value('achievements-switch'), isTrue);
    expect(find.byKey(const Key('achievements-tile')), findsOneWidget);
    expect(find.text('0 of 10 unlocked'), findsOneWidget);
  });

  appTest('switches persist, and sound needs celebrations', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      celebrate: true,
    );
    final kv = KvStore(app.db);
    SwitchListTile tile(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key)));

    await tester.tap(find.byKey(const Key('celebration-sound-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.celebrationSound), 'true');

    await tester.tap(find.byKey(const Key('celebrations-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.celebrations), 'false');
    expect(tile('celebration-sound-switch').onChanged, isNull);

    await tester.tap(find.byKey(const Key('achievements-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.achievements), 'false');
    expect(find.byKey(const Key('achievements-tile')), findsNothing);
  });

  appTest('stored switches are read at start', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      celebrate: true,
      seed: (db, _) => KvStore(db).set(KvKeys.celebrations, 'false'),
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('celebrations-switch')))
          .value,
      isFalse,
    );
  });

  appTest('the achievements tile opens the screen', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings, celebrate: true);
    await tester.tap(find.byKey(const Key('achievements-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });
}
