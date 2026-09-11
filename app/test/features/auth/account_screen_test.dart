import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
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

  appTest('the app bar says there is nobody signed in, and offers to be', (
    tester,
  ) async {
    await pumpApp(tester, overrides: overrides());

    // Today itself says the app is signed out, and is the way in.
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('account-action')))
          .tooltip,
      'Sign in to your server',
    );

    await tester.tap(find.byKey(const Key('account-action')));
    await tester.pumpAndSettle();
    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();

    // Back on Today, which now says who, rather than saying nothing.
    expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('account-action')))
          .tooltip,
      'Signed in as ben on https://nemo.test',
    );
  });

  appTest('a certificate nobody has vouched for is shown, then trusted', (
    tester,
  ) async {
    // The first attempt fails the way a handshake failure reaches the app.
    var refuse = true;
    final app = await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: [
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
          if (refuse) throw const ApiError(0, 'network');
          return (token: 'tok', username: username);
        }),
      ],
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

    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();

    // Not "could not reach the server": the certificate, to be looked at.
    expect(find.byKey(const Key('trust-certificate')), findsOneWidget);
    expect(find.text('CN=MUH Root CA'), findsOneWidget);
    expect(find.text('AB:CD:EF'), findsOneWidget);

    refuse = false;
    await tester.tap(find.byKey(const Key('trust-certificate-confirm')));
    await tester.pumpAndSettle();

    // Trusting it retried the sign-in, and it went through.
    expect(await storage.readToken(), 'tok');
    expect(
      CertificateTrust.decode(
        await KvStore(app.db).get(KvKeys.trustedCertificates),
      ),
      {'nemo.test': 'AB:CD:EF'},
    );
  });

  appTest('refusing the certificate says why nothing happened', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.account,
      overrides: overrides(failWith: const ApiError(0, 'network')),
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

    await fillIn(tester);
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.text("This device does not trust that server's certificate."),
      findsOneWidget,
    );
    expect(await storage.readToken(), isNull);
  });
}
