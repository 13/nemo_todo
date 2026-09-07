import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeSyncClient client;
  late MemoryAuthStorage storage;

  List<Object> overrides({
    ({String token, String username})? session,
    ApiError? failWith,
  }) => [
    authStorageProvider.overrideWithValue(storage),
    syncClientFactoryProvider.overrideWithValue((_, _) => client),
    sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
    authenticateProvider.overrideWithValue((
      dio, {
      required baseUrl,
      required username,
      required password,
      required signUp,
    }) async {
      if (failWith != null) throw failWith;
      return session ?? (token: 'tok', username: username);
    }),
  ];

  setUp(() {
    client = FakeSyncClient([]);
    storage = MemoryAuthStorage();
  });

  Future<void> fillIn(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('account-server')),
      'https://nemo.test',
    );
    await tester.enterText(find.byKey(const Key('account-username')), 'ben');
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'password123',
    );
  }

  appTest('rejects an address that is not a url', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: overrides(),
    );
    await tester.enterText(
      find.byKey(const Key('account-server')),
      'nemo.test',
    );
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid http(s) address.'), findsOneWidget);
    expect(client.calls, 0);
  });

  appTest('signing in stores the session and uploads local rows', (
    tester,
  ) async {
    client.responses.add(
      SyncResponse(
        cursor: 1,
        serverHlc: Hlc(
          millis: testNowMs + 1000,
          counter: 0,
          node: 'srv',
        ).toString(),
      ),
    );
    final app = await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: overrides(),
    );
    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();

    expect(await storage.readToken(), 'tok');
    final kv = KvStore(app.db);
    expect(await kv.get(KvKeys.serverUrl), 'https://nemo.test');
    expect(await kv.get(KvKeys.username), 'ben');
    // The inbox created at startup is offered to the new account.
    expect(client.pushes.single.map((c) => c.rowId), [app.inbox.id]);
  });

  appTest('a refused sign-in explains why', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: overrides(
        failWith: const ApiError(401, 'invalid_credentials'),
      ),
    );
    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong username or password.'), findsOneWidget);
    expect(await storage.readToken(), isNull);
  });

  appTest('a closed server explains that sign-up is disabled', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: overrides(failWith: const ApiError(403, 'signup_disabled')),
    );
    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-up')));
    await tester.pumpAndSettle();
    expect(
      find.text('This server does not allow new accounts.'),
      findsOneWidget,
    );
  });
}
