import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
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
}
