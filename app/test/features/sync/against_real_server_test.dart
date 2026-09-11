import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:nemo_server/nemo_server.dart' as server;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../support/test_db.dart';

/// The app talking to the real server over HTTP.
///
/// Every other sync test stands one side of the protocol on a fake of the
/// other, which is fast and says nothing about whether the two agree. This
/// one runs the actual request handler on a port and points the app's own
/// client at it, so a change to a field name, a status code or a JSON shape
/// on either side fails here rather than on a device.
void main() {
  late server.ServerDatabase serverDb;
  late HttpServer http;
  late String baseUrl;
  late AppDatabase db;
  late String token;

  setUp(() async {
    serverDb = server.ServerDatabase.memory();
    http = await shelf_io.serve(
      server.createHandler(
        db: serverDb,
        // No web app to serve, and sign-up open so the test can make an
        // account the way a first run does.
        config: const server.Config(
          allowSignup: true,
          webDir: '/nonexistent',
          version: '7.7.7',
        ),
      ),
      InternetAddress.loopbackIPv4,
      0,
    );
    baseUrl = 'http://${http.address.host}:${http.port}';
    db = testDatabase();

    token = (await SyncClient.authenticate(
      Dio(),
      baseUrl: baseUrl,
      username: 'ben',
      password: 'password123',
      signUp: true,
    )).token;
  });

  tearDown(() async {
    await http.close(force: true);
    await serverDb.close();
    await db.close();
  });

  /// The app, connected to that server, with nothing faked.
  Future<ProviderContainer> app() async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          AppBootstrap(
            nodeId: 'device',
            hlcLast: null,
            themeMode: ThemeMode.system,
            serverUrl: baseUrl,
            username: 'ben',
          ),
        ),
        nowProvider.overrideWithValue(() => testNow),
        authStorageProvider.overrideWithValue(MemoryAuthStorage(token)),
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).restore();
    return container;
  }

  test('a local task reaches the server and comes back', () async {
    final clock = testClock('device');
    final container = await app();
    await db.upsertList(
      TaskList(
        id: 'l1',
        name: 'Groceries',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );
    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'Buy milk',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );

    await container.read(syncEngineProvider.notifier).syncNow();

    expect(container.read(syncEngineProvider).status, SyncStatus.idle);
    expect(await db.outboxCount(), 0, reason: 'the server accepted them');

    final stored = await (serverDb.select(
      serverDb.tasks,
    )..where((t) => t.id.equals('t1'))).getSingleOrNull();
    expect(stored?.title, 'Buy milk');
    // The server decides ownership; the app is told what it decided.
    final list = await (serverDb.select(
      serverDb.lists,
    )..where((t) => t.id.equals('l1'))).getSingle();
    expect(list.ownerId, isNotNull);
  });

  test('a change made elsewhere arrives on the next sync', () async {
    final clock = testClock('device');
    final container = await app();
    await db.upsertList(
      TaskList(
        id: 'l1',
        name: 'Groceries',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );
    await container.read(syncEngineProvider.notifier).syncNow();

    // Another device, straight at the server, with a later stamp.
    final other = HlcClock(
      node: 'other',
      now: () => testNow.add(const Duration(minutes: 1)),
    );
    final client = SyncClient(Dio(), baseUrl: baseUrl, token: token);
    await client.sync(
      SyncRequest(
        cursor: 0,
        changes: [
          SyncChange.task(
            Task(
              id: 't9',
              listId: 'l1',
              title: 'Pick up parcel',
              sortKey: 'W',
              updatedAt: other.now().toString(),
            ),
          ),
        ],
      ),
    );

    await container.read(syncEngineProvider.notifier).syncNow();

    expect((await db.taskById('t9'))?.title, 'Pick up parcel');
  });

  test('a tombstone travels, and a stale edit loses to it', () async {
    final clock = testClock('device');
    final container = await app();
    await db.upsertList(
      TaskList(
        id: 'l1',
        name: 'Groceries',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );
    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'Buy milk',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );
    await container.read(syncEngineProvider.notifier).syncNow();

    // Deleted on another device, later than anything this one holds.
    final other = HlcClock(
      node: 'other',
      now: () => testNow.add(const Duration(minutes: 5)),
    );
    final stamp = other.now().toString();
    await SyncClient(Dio(), baseUrl: baseUrl, token: token).sync(
      SyncRequest(
        cursor: 0,
        changes: [
          SyncChange.task(
            Task(
              id: 't1',
              listId: 'l1',
              title: 'Buy milk',
              sortKey: 'V',
              updatedAt: stamp,
              deletedAt: stamp,
            ),
          ),
        ],
      ),
    );

    await container.read(syncEngineProvider.notifier).syncNow();

    expect((await db.taskById('t1'))?.isDeleted, isTrue);
  });

  test('a rejected session signs the app out rather than retrying', () async {
    final container = await app();
    // The token is revoked behind the app's back, which is what happens
    // when a session expires or someone signs out everywhere.
    await SyncClient(Dio(), baseUrl: baseUrl, token: token).logout();

    await container.read(syncEngineProvider.notifier).syncNow();

    expect(container.read(syncEngineProvider).status, SyncStatus.signedOut);
    expect(container.read(authControllerProvider).token, isNull);
  });

  test('the app learns which build the server is running', () async {
    final container = await app();

    await container.read(syncEngineProvider.notifier).syncNow();

    // Not a fake saying what it was told to say: a real server reporting
    // its own configured version across a real round trip.
    expect(container.read(syncEngineProvider).serverVersion, '7.7.7');
    expect(await KvStore(db).get(KvKeys.serverVersion), '7.7.7');
  });
}
