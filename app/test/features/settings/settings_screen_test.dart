import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/surface_tint.dart';
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

  appTest('style choice is applied and persisted', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);
    AppStyle style() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .extension<AppStyleTheme>()!
        .style;
    expect(style(), AppStyle.nemo);
    await tester.tap(find.text('macOS'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.appStyle), 'macos');
    expect(style(), AppStyle.macos);
  });

  appTest('a stored style is the one the app starts in', (tester) async {
    await pumpApp(
      tester,
      seed: (db, _) => KvStore(db).set(KvKeys.appStyle, 'material'),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme!.extension<AppStyleTheme>()!.style, AppStyle.material);
  });

  appTest('an accent choice is applied, persisted and undone', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);
    Color primary() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .colorScheme
        .primary;
    final own = primary();
    await tester.tap(find.byKey(const Key('accent-4')));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.accent), '4');
    expect(primary(), isNot(own));
    await tester.tap(find.byKey(const Key('accent-default')));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.accent), isNull);
    expect(primary(), own);
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

  appTest('a tint choice is applied and persisted', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);
    Color window() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .scaffoldBackgroundColor;
    final subtle = window();
    expect(find.byKey(const Key('surface-tint')), findsOneWidget);
    await tester.ensureVisible(find.text('Strong'));
    await tester.tap(find.text('Strong'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.surfaceTint), 'strong');
    expect(window(), isNot(subtle));
  });

  appTest('the tint shows only in the nemo style, and is kept', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      seed: (db, _) => KvStore(db).set(KvKeys.surfaceTint, 'none'),
    );
    Color window() => tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .scaffoldBackgroundColor;
    final none = window();
    await tester.tap(find.text('macOS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surface-tint')), findsNothing);
    await tester.tap(find.text('nemo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('surface-tint')), findsOneWidget);
    expect(await KvStore(app.db).get(KvKeys.surfaceTint), 'none');
    expect(window(), none);
  });

  appTest('a stored tint that is not a level starts as subtle', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      seed: (db, _) => KvStore(db).set(KvKeys.surfaceTint, 'loud'),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.scaffoldBackgroundColor, const Color(0xFFF5F8F8));
    final picker = tester.widget<SegmentedButton<SurfaceTint>>(
      find.byKey(const Key('surface-tint')),
    );
    expect(picker.selected, {SurfaceTint.subtle});
  });

  appTest('the tint is not offered in the material style', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      seed: (db, _) => KvStore(db).set(KvKeys.appStyle, 'material'),
    );
    expect(find.byKey(const Key('surface-tint')), findsNothing);
  });
}
