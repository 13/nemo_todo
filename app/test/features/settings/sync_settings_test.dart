import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
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

  List<Object> connected({String? token = 'secret'}) => [
    authStorageProvider.overrideWithValue(MemoryAuthStorage(token)),
    syncClientFactoryProvider.overrideWithValue((_, _) => client),
    sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
  ];

  setUp(() => client = FakeSyncClient([]));

  appTest('without an account it offers to connect', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings);
    expect(find.text('Connect to a server'), findsOneWidget);
    expect(
      find.text('Not connected. Your data stays on this device.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('connect-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-server')), findsOneWidget);
  });

  appTest('with an account it shows status and syncs on demand', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: connected(),
      settle: false,
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
      },
    );

    expect(find.text('Signed in as ben on https://nemo.test'), findsOneWidget);
    expect(find.text('1 change waiting'), findsOneWidget);

    client.responses.add(
      SyncResponse(
        cursor: 3,
        serverHlc: Hlc(
          millis: testNowMs + 1000,
          counter: 0,
          node: 'srv',
        ).toString(),
      ),
    );
    await tester.tap(find.byKey(const Key('sync-now')));
    await settleSync(tester);

    expect(client.pushes.single.map((c) => c.rowId), [app.inbox.id]);
    expect(await app.db.outboxCount(), 0);
    expect(find.text('Everything is synced'), findsOneWidget);
  });

  appTest('signing out keeps the tasks and returns to the local state', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: connected(),
      settle: false,
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
        await db.setListMeta({
          inbox.id: const [ListMember(username: 'ben', role: MemberRole.owner)],
        }, 'ben');
      },
    );
    await tester.tap(find.byKey(const Key('sign-out')));
    await settleSync(tester);
    await tester.tap(find.byKey(const Key('confirm-sign-out')));
    await settleSync(tester);

    expect(find.text('Connect to a server'), findsOneWidget);
    expect(await app.db.listById(app.inbox.id), isNotNull);
    // A plain query, not the stream: inside a widget test the fake clock
    // only advances while the test pumps, and an awaited stream would wait
    // for a tick that never comes.
    expect(await app.db.select(app.db.listMeta).get(), isEmpty);
    expect(await KvStore(app.db).get(KvKeys.serverUrl), isNull);
  });

  appTest('an offline sync says so and keeps the queue', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: connected(),
      settle: false,
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
      },
    );
    client.failWith = const ApiError(0, 'network');
    await tester.tap(find.byKey(const Key('sync-now')));
    await settleSync(tester);
    expect(find.textContaining('Offline. Changes will sync'), findsOneWidget);
    expect(await app.db.outboxCount(), 1);
  });
}
