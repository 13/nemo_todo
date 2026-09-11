import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/router.dart';

import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';

/// The web build: an account is not optional there.
void main() {
  late FakeSyncClient client;
  late MemoryAuthStorage storage;

  List<Object> overrides({ApiError? failWith}) => [
    authRequiredProvider.overrideWithValue(true),
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
      return (token: 'tok', username: username);
    }),
  ];

  setUp(() {
    client = FakeSyncClient([]);
    storage = MemoryAuthStorage();
  });

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('account-server')),
      'https://nemo.test',
    );
    await tester.enterText(find.byKey(const Key('account-username')), 'ben');
    await tester.enterText(
      find.byKey(const Key('account-password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('account-sign-in')));
    await tester.pumpAndSettle();
  }

  appTest('nothing is shown until someone signs in', (tester) async {
    await pumpApp(tester, overrides: overrides());

    // Today was asked for and the sign-in screen answered.
    expect(find.byKey(const Key('account-sign-in')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Nothing due today. Enjoy the calm.'), findsNothing);
    expect(
      find.textContaining('nemo keeps your tasks on this server'),
      findsOneWidget,
    );
    // Nothing to go back to, so nothing offers to.
    expect(find.byType(BackButton), findsNothing);
  });

  appTest('a bookmarked task is asked for again after signing in', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.search,
      overrides: overrides(),
    );
    expect(find.byKey(const Key('account-sign-in')), findsOneWidget);

    await signIn(tester);

    // Search, not Today: the address that was asked for survived the gate.
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('account-sign-in')), findsNothing);
  });

  appTest('a refused sign-in stays on the sign-in screen', (tester) async {
    await pumpApp(
      tester,
      overrides: overrides(
        failWith: const ApiError(401, 'invalid_credentials'),
      ),
    );
    await signIn(tester);
    expect(find.text('Wrong username or password.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  appTest('signing out empties the device and asks again', (tester) async {
    final app = await pumpApp(tester, overrides: overrides());
    await signIn(tester);
    await quickAdd(tester, 'Buy milk');
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This browser forgets your tasks'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-sign-out')));
    await tester.pumpAndSettle();

    // Back at the front door, with nothing of the last account left to
    // hand to the next one.
    expect(find.byKey(const Key('account-sign-in')), findsOneWidget);
    expect(find.text('Buy milk'), findsNothing);
    expect(await app.db.select(app.db.tasks).get(), isEmpty);
    expect(await app.db.select(app.db.subtasks).get(), isEmpty);
    // The Inbox is put back, so the next account has somewhere to write,
    // and it is the only thing waiting to be uploaded -- exactly what a
    // browser that has never been signed in on holds.
    final lists = await app.db.select(app.db.lists).get();
    expect(lists.map((l) => l.isInbox), [true]);
    expect((await app.db.outboxChanges()).map((c) => c.rowId), [
      lists.single.id,
    ]);
    expect(await KvStore(app.db).get(KvKeys.username), isNull);
  });
}
