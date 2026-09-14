import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';
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
    // Settings runs longer than the test's window; the tile is built only
    // once it is scrolled to.
    await scrollIntoView(tester, find.byKey(const Key('sign-out')));
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

  Future<TestApp> pumpConnected(WidgetTester tester) => pumpApp(
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

  Future<void> tapTile(WidgetTester tester, String key) async {
    // Settings runs longer than the test's window; the tile is built only
    // once it is scrolled to.
    await scrollIntoView(tester, find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await settleSync(tester);
  }

  appTest('changing the password sends both and says it is done', (
    tester,
  ) async {
    await pumpConnected(tester);
    await tapTile(tester, 'change-password');
    await tester.enterText(
      find.byKey(const Key('change-password-current')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('change-password-new')),
      'a-new-password',
    );
    await tester.tap(find.byKey(const Key('change-password-confirm')));
    await settleSync(tester);

    expect(client.passwordChanges, ['password123>a-new-password']);
    expect(
      find.text('Password changed. Your other devices have been signed out.'),
      findsOneWidget,
    );
    expect(find.text('Signed in as ben on https://nemo.test'), findsOneWidget);
  });

  appTest('a wrong current password keeps the dialog open and says so', (
    tester,
  ) async {
    await pumpConnected(tester);
    await tapTile(tester, 'change-password');
    client.failWith = const ApiError(403, 'wrong_password');
    await tester.tap(find.byKey(const Key('change-password-confirm')));
    await settleSync(tester);

    expect(find.text('That is not your password.'), findsOneWidget);
    expect(find.byKey(const Key('change-password-confirm')), findsOneWidget);
    client.failWith = null;
  });

  appTest('deleting the account signs out and keeps the tasks here', (
    tester,
  ) async {
    final app = await pumpConnected(tester);
    await tapTile(tester, 'delete-account');
    expect(
      find.textContaining('This deletes your account on https://nemo.test.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Your tasks stay on this device.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('delete-account-password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await settleSync(tester);

    expect(client.deletions, ['password123']);
    expect(find.text('Account deleted.'), findsOneWidget);
    expect(find.text('Connect to a server'), findsOneWidget);
    expect(await app.db.listById(app.inbox.id), isNotNull);
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

  appTest('a certificate the sync choked on is shown and can be trusted', (
    tester,
  ) async {
    // How a handshake the device cannot verify reaches the engine.
    client.failWith = const ApiError(0, 'network');
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
    app.container
        .read(certificateTrustProvider)
        .refused(
          ServerCertificate(
            host: 'nemo.test',
            subject: 'CN=nemo.test',
            issuer: 'CN=MUH Root CA',
            expires: DateTime(2036, 9, 5),
            fingerprint: 'AB:CD:EF',
          ),
        );

    await tester.tap(find.byKey(const Key('sync-now')));
    await settleSync(tester);

    // Not "offline": the server answered, with a certificate nothing here
    // vouches for, and it is on screen to be looked at.
    expect(find.byKey(const Key('sync-untrusted-certificate')), findsOneWidget);
    expect(
      find.text("This device does not trust that server's certificate."),
      findsOneWidget,
    );
    expect(find.textContaining('Offline.'), findsNothing);

    client.failWith = null;
    // Settings runs longer than the test's window; the banner is built only
    // once it is scrolled to.
    await scrollIntoView(tester, find.byKey(const Key('review-certificate')));
    await tester.tap(find.byKey(const Key('review-certificate')));
    await tester.pumpAndSettle();
    expect(find.text('CN=MUH Root CA'), findsOneWidget);
    expect(find.text('AB:CD:EF'), findsOneWidget);

    final before = client.calls;
    await tester.tap(find.byKey(const Key('trust-certificate-confirm')));
    await settleSync(tester);

    // Trusting it ran the sync that failed on it, and the warning is gone.
    expect(client.calls, greaterThan(before));
    expect(
      CertificateTrust.decode(
        await KvStore(app.db).get(KvKeys.trustedCertificates),
      ),
      {'nemo.test': 'AB:CD:EF'},
    );
    expect(find.byKey(const Key('sync-untrusted-certificate')), findsNothing);
  });
}
