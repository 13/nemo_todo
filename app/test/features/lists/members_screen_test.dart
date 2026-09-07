import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_sync.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeSyncClient client;

  const owners = [
    ListMember(username: 'ben', role: MemberRole.owner),
    ListMember(username: 'anna', role: MemberRole.editor),
  ];

  setUp(() => client = FakeSyncClient([]));

  appTest('without an account sharing is unavailable', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/lists/inbox/members');
    expect(find.text('Connect to a server to share lists.'), findsOneWidget);
    expect(app.inbox.id, isNotEmpty);
  });

  appTest('an owner adds and removes a member', (tester) async {
    late String listId;
    await pumpApp(
      tester,
      initialLocation: '/lists/seeded/members',
      overrides: [
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
      settle: false,
      seed: (db, inbox) async {
        listId = 'seeded';
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
        await db.upsertList(
          TaskList(
            id: listId,
            name: 'Groceries',
            sortKey: 'V',
            updatedAt: '1789000000000-0000-seed',
          ),
        );
        await db.setListMeta({listId: owners}, 'ben');
        // The server keeps reporting the same membership as syncs run.
        client.memberMap = {listId: owners};
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('ben (you)'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('anna'), findsOneWidget);
    expect(find.text('Editor'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('member-username')), 'carla');
    await tester.tap(find.byKey(const Key('member-add')));
    await settleSync(tester);
    expect(client.shared, ['seeded:carla:editor']);

    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Remove anna'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(client.unshared, ['seeded:anna']);
  });

  appTest('an unknown username is reported', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/lists/seeded/members',
      overrides: [
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
      seed: (db, inbox) async {
        final kv = KvStore(db);
        await kv.set(KvKeys.serverUrl, 'https://nemo.test');
        await kv.set(KvKeys.username, 'ben');
        await db.upsertList(
          const TaskList(
            id: 'seeded',
            name: 'Groceries',
            sortKey: 'V',
            updatedAt: '1789000000000-0000-seed',
          ),
        );
      },
      settle: false,
    );
    client.failWith = const ApiError(404, 'unknown_user');
    await tester.enterText(find.byKey(const Key('member-username')), 'nobody');
    await tester.tap(find.byKey(const Key('member-add')));
    await settleSync(tester);
    expect(find.text('No user with that name.'), findsOneWidget);
  });
}
