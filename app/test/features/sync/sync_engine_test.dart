import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_sync.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeSyncClient client;

  // Later than anything the device clock issues, so the server wins ties
  // of intent the way it would in real life.
  final serverHlc = Hlc(
    millis: testNow.millisecondsSinceEpoch + 1000,
    counter: 0,
    node: 'srv',
  ).toString();

  TaskList list(String id, String stamp) =>
      TaskList(id: id, name: 'L', sortKey: 'V', updatedAt: stamp);
  Task task(String id, String stamp, {String title = 'T'}) =>
      Task(id: id, listId: 'l1', title: title, sortKey: 'V', updatedAt: stamp);

  /// A container wired to the in-memory database and the fake client, with
  /// an account already connected.
  Future<ProviderContainer> container({bool connected = true}) async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          const AppBootstrap(
            nodeId: 'device',
            hlcLast: null,
            themeMode: ThemeMode.system,
            serverUrl: 'https://nemo.test',
            username: 'ben',
          ),
        ),
        nowProvider.overrideWithValue(() => testNow),
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        // No live-update stream in tests: it would try to reach the network.
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
    );
    addTearDown(c.dispose);
    if (connected) {
      // The real path: the stored token turns into a live session.
      await c.read(authControllerProvider.notifier).restore();
    }
    return c;
  }

  setUp(() {
    db = testDatabase();
    client = FakeSyncClient([]);
  });
  tearDown(() => db.close());

  test(
    'pushes queued rows, applies the answer and stores the cursor',
    () async {
      final clock = testClock('device');
      await db.upsertList(list('l1', clock.now().toString()));
      await db.upsertTask(task('t1', clock.now().toString()));
      client.responses.add(
        SyncResponse(
          cursor: 12,
          serverHlc: serverHlc,
          changes: [SyncChange.task(task('t2', '0000000000008-0000-other'))],
          members: const {
            'l1': [
              ListMember(username: 'ben', role: MemberRole.owner),
              ListMember(username: 'anna', role: MemberRole.editor),
            ],
          },
        ),
      );

      final c = await container();
      await c.read(syncEngineProvider.notifier).syncNow();

      expect(client.pushes.single.map((x) => x.rowId), ['l1', 't1']);
      expect(client.cursors.single, 0);
      expect(
        await db.outboxCount(),
        0,
        reason: 'accepted rows leave the queue',
      );
      expect((await db.taskById('t2'))!.title, 'T');
      expect(await KvStore(db).get(KvKeys.cursor), '12');
      final meta = await db.watchListMeta().first;
      expect(meta['l1']!.myRole, MemberRole.owner);
      expect(meta['l1']!.isShared, isTrue);
      final state = c.read(syncEngineProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.lastSyncAt, testNow);
      expect(state.pending, 0);
    },
  );

  test('follows hasMore until the server is done', () async {
    client.responses.addAll([
      SyncResponse(
        cursor: 1,
        serverHlc: serverHlc,
        hasMore: true,
        changes: [SyncChange.list(list('l1', '0000000000002-0000-other'))],
      ),
      SyncResponse(
        cursor: 2,
        serverHlc: serverHlc,
        changes: [SyncChange.task(task('t1', '0000000000003-0000-other'))],
      ),
    ]);

    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.calls, 2);
    expect(client.cursors, [0, 1]);
    expect(client.pushes.last, isEmpty, reason: 'later pages are pure pulls');
    expect(await db.listById('l1'), isNotNull);
    expect(await db.taskById('t1'), isNotNull);
    expect(await KvStore(db).get(KvKeys.cursor), '2');
  });

  test('a rejected change is dropped and replaced by the server row', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString(), title: 'mine'));
    client.responses.add(
      SyncResponse(
        cursor: 4,
        serverHlc: serverHlc,
        rejected: const [
          RejectedChange(
            entity: SyncEntity.task,
            rowId: 't1',
            reason: 'forbidden',
          ),
        ],
        changes: [SyncChange.task(task('t1', serverHlc, title: 'theirs'))],
      ),
    );

    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(await db.outboxCount(), 0);
    expect((await db.taskById('t1'))!.title, 'theirs');
    expect(c.read(syncEngineProvider).discarded, 1);
    c.read(syncEngineProvider.notifier).clearDiscarded();
    expect(c.read(syncEngineProvider).discarded, 0);
  });

  test('an edit made during a push stays queued', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString(), title: 'first'));
    final queued = await db.outboxChanges();
    await db.upsertTask(task('t1', clock.now().toString(), title: 'second'));
    await db.ackOutbox(queued);
    expect(await db.outboxCount(), 1);
    expect(
      ((await db.outboxChanges()).single as SyncChangeTask).row.title,
      'second',
    );
  });

  test('an unreachable server leaves the queue intact', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString()));
    client.failWith = const ApiError(0, 'network');

    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    final state = c.read(syncEngineProvider);
    expect(state.status, SyncStatus.offline);
    expect(state.error, 'network');
    expect(await db.outboxCount(), 1);
  });

  test('a rejected token signs the session out but keeps the data', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString()));
    client.failWith = const ApiError(401, 'unauthorized');

    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(c.read(syncEngineProvider).status, SyncStatus.signedOut);
    expect(c.read(authControllerProvider).token, isNull);
    expect(c.read(authControllerProvider).serverUrl, 'https://nemo.test');
    expect(await db.taskById('t1'), isNotNull);
  });

  test('without an account nothing is sent', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString()));
    final c = await container(connected: false);
    await c.read(syncEngineProvider.notifier).syncNow();
    expect(client.calls, 0);
    expect(c.read(syncEngineProvider).status, SyncStatus.local);
  });

  test('signing in offers every local row to the server', () async {
    final clock = testClock('device');
    await db.upsertList(list('l1', clock.now().toString()));
    await db.upsertTask(task('t1', clock.now().toString()));
    await db.clearOutbox();
    client.responses.add(SyncResponse(cursor: 1, serverHlc: serverHlc));

    final c = await container();
    await c.read(syncEngineProvider.notifier).onSignedIn();

    expect(client.pushes.single.map((x) => x.rowId), ['l1', 't1']);
  });

  test('signing out clears sharing metadata and stops syncing', () async {
    await db.setListMeta({
      'l1': const [ListMember(username: 'ben', role: MemberRole.owner)],
    }, 'ben');
    final c = await container();
    await c.read(syncEngineProvider.notifier).onSignedOut();
    expect(await db.watchListMeta().first, isEmpty);
    expect(c.read(syncEngineProvider).status, SyncStatus.local);
  });
}
