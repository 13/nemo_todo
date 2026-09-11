import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/settings/ui/about_tile.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeSyncClient client;

  /// A connected account. [web] decides whether this build is one the
  /// server handed over, and [appVersion] stands in for what
  /// `package_info` reports, which under test is nothing at all.
  List<Object> connected({bool web = false, AppVersion? appVersion}) => [
    authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
    syncClientFactoryProvider.overrideWithValue((_, _) => client),
    sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
    servedByServerProvider.overrideWithValue(web),
    if (appVersion != null)
      currentVersionProvider.overrideWith((_) async => appVersion),
  ];

  setUp(() {
    client = FakeSyncClient([]);
  });

  Future<void> open(
    WidgetTester tester, {
    required List<Object> overrides,
    String? serverVersion,
  }) async {
    if (serverVersion != null) {
      client.responses.add(
        SyncResponse(
          cursor: 1,
          serverHlc: Hlc(
            millis: testNowMs + 1000,
            counter: 0,
            node: 'srv',
          ).toString(),
          serverVersion: serverVersion,
        ),
      );
    }
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: overrides,
      settle: false,
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
      },
    );
    // Driven rather than waited for: the engine syncs on a debounce that
    // the app's own startup kicks, and pumpApp does not run that.
    if (serverVersion != null) {
      await app.container.read(syncEngineProvider.notifier).syncNow();
    }
    await settleSync(tester);
  }

  appTest('with no account it names this build alone', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings);
    // package_info reports nothing under test, so this is about the shape
    // rather than the number: one version, no server, no warning.
    expect(find.textContaining('Version'), findsOneWidget);
    expect(find.textContaining('Server'), findsNothing);
    expect(find.byKey(const Key('about-stale')), findsNothing);
  });

  appTest('connected, it names the server beside this build', (tester) async {
    await open(
      tester,
      overrides: connected(appVersion: const AppVersion(0, 4, 0)),
      serverVersion: '0.4.0',
    );
    expect(find.textContaining('App 0.4.0 · Server 0.4.0'), findsOneWidget);
    expect(find.byKey(const Key('about-stale')), findsNothing);
  });

  appTest('a server too old to say is not called a mismatch', (tester) async {
    await open(tester, overrides: connected(), serverVersion: '');
    expect(find.textContaining('Server'), findsNothing);
    expect(find.textContaining('Version'), findsOneWidget);
    expect(find.byKey(const Key('about-stale')), findsNothing);
  });

  appTest('a page older than its server says so, and says to reload', (
    tester,
  ) async {
    await open(
      tester,
      overrides: connected(web: true, appVersion: const AppVersion(0, 3, 0)),
      serverVersion: '9.9.9',
    );
    expect(find.textContaining('App 0.3.0 · Server 9.9.9'), findsOneWidget);
    expect(find.byKey(const Key('about-stale')), findsOneWidget);
    expect(find.textContaining('Reload'), findsOneWidget);
  });

  appTest('an installed app behind its server is told to reload nothing', (
    tester,
  ) async {
    // Android: being behind is ordinary, and the update tile offers the
    // download. Telling someone to reload a page they do not have would be
    // advice nobody can take.
    await open(
      tester,
      overrides: connected(appVersion: const AppVersion(0, 3, 0)),
      serverVersion: '9.9.9',
    );
    // The same gap as the web case above, and deliberately silent here.
    expect(find.textContaining('App 0.3.0 · Server 9.9.9'), findsOneWidget);
    expect(find.byKey(const Key('about-stale')), findsNothing);
  });

  test('behind means both parsed and the server ahead', () {
    const app = AppVersion(0, 4, 0);
    expect(AboutTile.appIsBehind(app, '0.5.0'), isTrue);
    expect(AboutTile.appIsBehind(app, '0.4.0'), isFalse);
    expect(AboutTile.appIsBehind(app, '0.3.9'), isFalse);
    // Nothing to compare is never a mismatch.
    expect(AboutTile.appIsBehind(app, ''), isFalse);
    expect(AboutTile.appIsBehind(app, null), isFalse);
    expect(AboutTile.appIsBehind(null, '9.9.9'), isFalse);
    expect(AboutTile.appIsBehind(app, 'nightly'), isFalse);
  });
}
