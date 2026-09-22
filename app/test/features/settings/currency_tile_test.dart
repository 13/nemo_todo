import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';

void main() {
  // The test locale resolves to 'en_US', whose currency is 'USD' -- this is
  // production behaviour, not a test-environment artefact: `defaultCurrencyCode`
  // reads `PlatformDispatcher.instance.locale`, and a device set to en_US
  // gets USD as its default the same way this test's locale does. Choosing
  // CHF -- not the default -- is what actually proves the choice is
  // persisted rather than merely that the sheet opened and a no-op tap on
  // the current value trivially matched it.
  appTest('choosing a currency keeps it', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.settings);

    // The tile sits below the fold on the test viewport, alongside the
    // rest of settings; scroll it into view the way the other settings
    // tests reach a tile past the top of the list.
    await scrollIntoView(tester, find.byKey(const Key('currency-tile')));
    await tester.tap(find.byKey(const Key('currency-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHF').last);
    await tester.pumpAndSettle();

    expect(await KvStore(app.db).get(KvKeys.currency), 'CHF');
    expect(find.textContaining('CHF'), findsWidgets);
  });
}
