import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/router.dart';

import '../../support/fake_updates.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeReleaseClient client;
  late FakeInstaller installer;

  List<Object> overrides({bool supported = true}) => [
    updatesSupportedProvider.overrideWithValue(supported),
    currentVersionProvider.overrideWith((_) async => const AppVersion(0, 1, 0)),
    deviceAbisProvider.overrideWith((_) async => ['arm64-v8a']),
    releaseClientProvider.overrideWithValue(client),
    apkInstallerProvider.overrideWithValue(installer),
  ];

  setUp(() {
    client = FakeReleaseClient();
    installer = FakeInstaller();
  });

  appTest('settings offers a check and reports the result', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: overrides(),
    );
    expect(find.text('Updates'), findsOneWidget);
    expect(find.textContaining('You have version 0.1.0'), findsWidgets);

    await tester.tap(find.byKey(const Key('check-for-updates')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 0.2.0 is available'), findsOneWidget);
  });

  appTest('a failure names itself when you asked for it', (tester) async {
    client.failure = UpdateFailure.rateLimited;
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: overrides(),
    );
    await tester.tap(find.byKey(const Key('check-for-updates')));
    await tester.pumpAndSettle();
    expect(find.textContaining('rate limiting'), findsOneWidget);
  });

  appTest('the banner appears on Today and can be waved away', (tester) async {
    final app = await pumpApp(tester, overrides: overrides());
    await app.container
        .read(updateControllerProvider.notifier)
        .check(manual: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-banner-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  appTest('nothing shows where updates are unsupported', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: overrides(supported: false),
    );
    expect(find.text('Updates'), findsNothing);
  });
}
