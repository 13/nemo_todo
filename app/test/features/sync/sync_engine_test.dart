import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_sync.dart';
import '../../support/photos.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late MemoryPhotoStore store;
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
  Future<ProviderContainer> container({
    bool connected = true,
    RetryPolicy? retry,
    String username = 'ben',
    // Riverpod does not export the type of its overrides; see pumpApp.
    List<Object> extra = const [],
  }) async {
    final c = ProviderContainer(
      overrides: [
        if (retry != null) syncRetryPolicyProvider.overrideWithValue(retry),
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          AppBootstrap(
            nodeId: 'device',
            hlcLast: null,
            themeMode: ThemeMode.system,
            serverUrl: 'https://nemo.test',
            username: username,
          ),
        ),
        nowProvider.overrideWithValue(() => testNow),
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        // No live-update stream in tests: it would try to reach the network.
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
        photoStoreProvider.overrideWithValue(store),
        ...extra.cast(),
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
    store = MemoryPhotoStore();
    client = FakeSyncClient([]);
  });
  tearDown(() => db.close());

  const fastRetry = (
    initial: Duration(milliseconds: 10),
    max: Duration(milliseconds: 20),
  );

  /// Waits until [done] holds, or two seconds pass, whichever comes first.
  Future<void> eventually(FutureOr<bool> Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!await done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Clearly longer than [fastRetry] would take to try again, several times.
  const noRetryWindow = Duration(milliseconds: 200);

  test('an Inbox arriving beside ours leaves one Inbox, not two', () async {
    // This device was used offline, so it made its own Inbox; the account
    // it is now connecting to already had one.
    final repo = ListsRepository(db, testClock('device'), sequentialIds('l'));
    final mine = await repo.ensureInbox();
    await db.upsertTask(
      Task(
        id: 't1',
        listId: mine.id,
        title: 'Buy milk',
        sortKey: 'V',
        updatedAt: testClock('device').now().toString(),
      ),
    );
    client.responses.add(
      SyncResponse(
        cursor: 4,
        serverHlc: serverHlc,
        changes: [
          const SyncChange.list(
            TaskList(
              id: 'a-inbox-from-elsewhere',
              name: 'Inbox',
              sortKey: 'V',
              isInbox: true,
              icon: 'inbox',
              updatedAt: '0000000000008-0000-other',
            ),
          ),
        ],
      ),
    );

    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    // Settled by the sync that caused it, rather than left to blow up in
    // the startup path at the next launch.
    final inboxes = (await db.select(db.lists).get()).where(
      (l) => l.isInbox && l.deletedAt == null,
    );
    expect(inboxes.map((l) => l.id), ['a-inbox-from-elsewhere']);
    expect((await db.taskById('t1'))!.listId, 'a-inbox-from-elsewhere');
  });

  test('tells the server it can read photo changes', () async {
    // A server only sends photo changes to clients that say so, because
    // apps from before photos cannot decode them.
    client.responses.add(
      SyncResponse(cursor: 1, serverHlc: serverHlc, hasMore: true),
    );
    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.requests, hasLength(2));
    expect(client.requests.map((r) => r.photos), everyElement(isTrue));
  });

  test('remembers which build the server said it was running', () async {
    client.responses.add(
      SyncResponse(cursor: 1, serverHlc: serverHlc, serverVersion: '9.9.9'),
    );
    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(c.read(syncEngineProvider).serverVersion, '9.9.9');
    // Stored, so Settings can name the server before the first sync of the
    // next session and while offline.
    expect(await KvStore(db).get(KvKeys.serverVersion), '9.9.9');
  });

  test('a server too old to name itself is recorded as having not', () async {
    client.responses.add(SyncResponse(cursor: 1, serverHlc: serverHlc));
    final c = await container();
    await c.read(syncEngineProvider.notifier).syncNow();

    // Empty, not null: it answered, it just did not say. Settings shows
    // the app version alone rather than claiming a mismatch.
    expect(c.read(syncEngineProvider).serverVersion, isEmpty);
  });

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
    final queued = await db.outboxChanges(includePhotos: true);
    await db.upsertTask(task('t1', clock.now().toString(), title: 'second'));
    await db.ackOutbox(queued);
    expect(await db.outboxCount(), 1);
    expect(
      ((await db.outboxChanges(includePhotos: true)).single as SyncChangeTask)
          .row
          .title,
      'second',
    );
  });

  test(
    'a server row that wins a race with a local edit drains the queue',
    () async {
      final clock = testClock('device');
      await db.upsertTask(task('t1', clock.now().toString(), title: 'first'));

      // The user edits again while the push is in flight, so the queue entry
      // no longer carries the stamp that was sent, and the server's answer
      // then turns out to be newer than either.
      client.duringSync = () =>
          db.upsertTask(task('t1', clock.now().toString(), title: 'second'));
      client.responses.add(
        SyncResponse(
          cursor: 5,
          serverHlc: serverHlc,
          changes: [SyncChange.task(task('t1', serverHlc, title: 'server'))],
        ),
      );

      final c = await container();
      await c.read(syncEngineProvider.notifier).syncNow();

      expect((await db.taskById('t1'))!.title, 'server');
      expect(
        await db.outboxCount(),
        0,
        reason: 'the queued edit lost, and would otherwise be resent forever',
      );

      // A second round has nothing left to say.
      await c.read(syncEngineProvider.notifier).syncNow();
      expect(client.pushes.last, isEmpty);
    },
  );

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

  test('a failed sync tries itself again, waiting longer each time', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString()));
    client.failWith = const ApiError(500, 'internal');

    final c = await container(
      retry: (
        initial: const Duration(milliseconds: 10),
        max: const Duration(milliseconds: 20),
      ),
    );
    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).status, SyncStatus.error);
    expect(client.calls, 1);

    // Nothing here edits a row, resumes the app or reconnects a stream.
    // Before the engine scheduled its own retry, that meant the queue sat
    // there until the user did something.
    await eventually(() => client.calls > 1);
    expect(client.calls, greaterThan(1));

    client.failWith = null;
    await eventually(
      () => c.read(syncEngineProvider).status == SyncStatus.idle,
    );
    expect(c.read(syncEngineProvider).status, SyncStatus.idle);
    expect(await db.outboxCount(), 0);
  });

  test('a rejected token stops the retries', () async {
    final clock = testClock('device');
    await db.upsertTask(task('t1', clock.now().toString()));
    client.failWith = const ApiError(401, 'unauthorized');

    final c = await container(
      retry: (
        initial: const Duration(milliseconds: 10),
        max: const Duration(milliseconds: 20),
      ),
    );
    await c.read(syncEngineProvider.notifier).syncNow();
    final calls = client.calls;

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(
      client.calls,
      calls,
      reason: 'retrying a dead session only spends battery',
    );
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

  PhotosRepository photos() =>
      PhotosRepository(db, testClock('a'), sequentialIds('p'), store);

  /// A pulled photo row, naming bytes this device does not hold.
  SyncResponse pulledPhoto(String hash) {
    final stamp = Hlc(millis: testNowMs, counter: 0, node: 'srv').toString();
    return SyncResponse(
      cursor: 1,
      serverHlc: stamp,
      changes: [
        SyncChange.task(task('t1', stamp)),
        SyncChange.photo(
          Photo(
            id: 'p1',
            parentId: 't1',
            sha256: hash,
            byteSize: 3,
            width: 1,
            height: 1,
            sortKey: 'V',
            updatedAt: stamp,
          ),
        ),
      ],
    );
  }

  test('bytes are uploaded before the row that names them is pushed', () async {
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploaded, [photo.sha256]);
    final pushed = client.pushes.expand((c) => c).whereType<SyncChangePhoto>();
    expect(pushed.single.row.id, photo.id);
    expect(
      client.uploadedBefore(photo.sha256),
      isTrue,
      reason:
          'a row the server cannot serve bytes for is a broken picture '
          'on every other device',
    );
    expect(await db.pendingBlobs(), isEmpty);
  });

  /// A picture this device already uploaded to the account in [account],
  /// with its row waiting to be offered again by a sign-in.
  Future<Photo> syncedPicture(String account) async {
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;
    await db.markBlobSynced(photo.sha256);
    await store.unpin(photo.sha256);
    await db.clearOutbox();
    await KvStore(db).set(KvKeys.blobAccount, account);
    return photo;
  }

  test(
    'signing in to another account uploads the bytes again, first',
    () async {
      final photo = await syncedPicture('https://nemo.test|anna');
      final c = await container();

      await c.read(syncEngineProvider.notifier).onSignedIn();

      expect(client.uploaded, [photo.sha256]);
      expect(client.pushedPhotoHashes, [
        photo.sha256,
      ], reason: 'the row is still offered to the new account');
      expect(
        client.uploadedBefore(photo.sha256),
        isTrue,
        reason: 'the new server has never had these bytes',
      );
      expect(await db.pendingBlobs(), isEmpty);
      expect(
        await KvStore(db).get(KvKeys.blobAccount),
        'https://nemo.test|ben',
      );
    },
  );

  test('signing in to the same account again uploads nothing', () async {
    final photo = await syncedPicture('https://nemo.test|ben');
    final c = await container();

    await c.read(syncEngineProvider.notifier).onSignedIn();

    expect(client.uploaded, isEmpty);
    expect(client.pushedPhotoHashes, [photo.sha256]);
  });

  test('a first sign-in does not upload what is already synced', () async {
    final photo = await syncedPicture('unused');
    await KvStore(db).set(KvKeys.blobAccount, null);
    final c = await container();

    await c.read(syncEngineProvider.notifier).onSignedIn();

    expect(client.uploaded, isEmpty);
    expect(client.pushedPhotoHashes, [photo.sha256]);
    expect(await KvStore(db).get(KvKeys.blobAccount), 'https://nemo.test|ben');
  });

  test(
    'a device that only ever downloaded pictures still knows whose they '
    'are, and uploads them before a different account gets the rows',
    () async {
      const hash =
          '1111111111111111111111111111111111111111111111111111111111111111';
      client.responses.add(pulledPhoto(hash));
      client.blobs[hash] = Uint8List.fromList([1, 2, 3]);
      // Signed in before the app was upgraded, so no sign-in ever recorded
      // the account, and nothing was uploaded to record it either.
      final first = await container(
        extra: [photoDownloadEagerProvider.overrideWithValue(true)],
      );
      await first.read(syncEngineProvider.notifier).syncNow();
      expect((await db.select(db.blobs).get()).single.state, 'synced');
      expect(
        await KvStore(db).get(KvKeys.blobAccount),
        'https://nemo.test|ben',
      );
      first.dispose();

      // Anna signs in on the same device, against a server without the bytes.
      client = FakeSyncClient([]);
      final second = await container(username: 'anna');
      await second.read(syncEngineProvider.notifier).onSignedIn();

      expect(client.uploaded, [hash]);
      expect(client.pushedPhotoHashes, [hash]);
      expect(client.uploadedBefore(hash), isTrue);
    },
  );

  test(
    'switching account re-uploads only the pictures this device holds',
    () async {
      // Room for both pictures, so only the one removed below is missing.
      store = MemoryPhotoStore(maxEntries: 2);
      await db.upsertTask(task('t1', testClock('a').now().toString()));
      final repo = photos();
      final held = (await repo.add(
        PhotoParent.task,
        't1',
        smallJpeg(width: 10),
      ))!;
      final gone = (await repo.add(
        PhotoParent.task,
        't1',
        smallJpeg(width: 30),
      ))!;
      for (final p in [held, gone]) {
        await db.markBlobSynced(p.sha256);
        await store.unpin(p.sha256);
      }
      // Evicted, or a browser tab that was reloaded: the bytes are not here.
      await store.remove(gone.sha256);
      await db.clearOutbox();
      await KvStore(db).set(KvKeys.blobAccount, 'https://nemo.test|anna');
      // The upload fails, so what the switch left behind can be inspected.
      client.blobFailures[held.sha256] = const ApiError(0, 'network');
      final c = await container();

      await c.read(syncEngineProvider.notifier).onSignedIn();

      expect((await db.pendingBlobs()).map((b) => b.sha256), [held.sha256]);
      final goneRow = await (db.select(
        db.blobs,
      )..where((t) => t.sha256.equals(gone.sha256))).getSingle();
      expect(
        goneRow.state,
        'synced',
        reason: 'nothing to upload, and pending would hold its row forever',
      );
      expect(client.pushedPhotoHashes, [gone.sha256]);
      for (var i = 0; i < 3; i++) {
        await store.put('filler$i', Uint8List.fromList([i]));
      }
      expect(
        await store.get(held.sha256),
        isNotNull,
        reason: 'pinned: the upload to come is its only other copy',
      );
    },
  );

  /// A task, and a picture added and then deleted, on a device whose server
  /// has no photo support: the upload was refused, and the delete forgot
  /// the blob, so only the flag holds the tombstone back.
  Future<({ProviderContainer c, Photo photo})> deletedOnOldServer() async {
    client
      ..photos = false
      ..rejectPhotoChanges = true;
    final c = await container();
    await db.upsertList(list('l1', testClock('a').now().toString()));
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final repo = photos();
    final photo = (await repo.add(PhotoParent.task, 't1', smallJpeg()))!;
    client.blobFailures[photo.sha256] = const ApiError(404, 'not_found');
    await c.read(syncEngineProvider.notifier).syncNow();
    await repo.delete(photo.id);
    await db.upsertTask(task('t2', testClock('a').now().toString()));
    return (c: c, photo: photo);
  }

  test('a server without photos gets no photo change, and the tasks', () async {
    final (:c, :photo) = await deletedOnOldServer();

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.pushedPhotoHashes, isEmpty);
    expect(client.pushes.expand((p) => p).map((x) => x.rowId), contains('t2'));
    final state = c.read(syncEngineProvider);
    expect(state.status, SyncStatus.idle);
    expect(state.error, isNull);
    expect(await KvStore(db).get(KvKeys.serverPhotos), 'false');
    expect((await db.select(db.outbox).get()).map((e) => e.rowId), [
      photo.id,
    ], reason: 'the tombstone waits for a server that can take it');
  });

  test('once the server says it takes photos, the held ones go out', () async {
    final (:c, :photo) = await deletedOnOldServer();
    await c.read(syncEngineProvider.notifier).syncNow();

    client
      ..photos = true
      ..rejectPhotoChanges = false;
    final before = client.calls;
    await c.read(syncEngineProvider.notifier).syncNow();

    final pushed = client.pushes
        .skip(before)
        .expand((p) => p)
        .whereType<SyncChangePhoto>();
    expect(pushed.single.row.id, photo.id);
    expect(pushed.single.row.deletedAt, isNotNull);
    expect(client.calls - before, 2, reason: 'in the same sync, not the next');
    expect(await db.outboxCount(), 0);
    expect(await KvStore(db).get(KvKeys.serverPhotos), 'true');
  });

  test('a server that said it has no photos is not sent their bytes, '
      'until it says it has', () async {
    await KvStore(db).set(KvKeys.serverPhotos, 'false');
    client
      ..photos = false
      ..rejectPhotoChanges = true;
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;

    await c.read(syncEngineProvider.notifier).syncNow();
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploadAttempts, 0);
    expect(client.pushedPhotoHashes, isEmpty);
    expect(client.pushes.expand((p) => p).map((x) => x.rowId), contains('t1'));
    final held = c.read(syncEngineProvider);
    expect(held.status, SyncStatus.idle);
    expect(held.error, isNull);

    client
      ..photos = true
      ..rejectPhotoChanges = false;
    final before = client.calls;
    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploaded, [photo.sha256]);
    expect(client.pushedPhotoHashes, [photo.sha256]);
    expect(client.uploadedBefore(photo.sha256), isTrue);
    expect(
      client.calls - before,
      2,
      reason:
          'one round sees the flip and holds, the sync-again round '
          'uploads and pushes',
    );
  });

  test('a server rolled back to one without photos is noticed', () async {
    await KvStore(db).set(KvKeys.serverPhotos, 'true');
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    await photos().add(PhotoParent.task, 't1', smallJpeg());
    client
      ..photos = false
      ..rejectPhotoChanges = true;

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).error, 'bad_request');
    expect(await KvStore(db).get(KvKeys.serverPhotos), 'false');

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).status, SyncStatus.idle);
    expect(await db.taskById('t1'), isNotNull);
    expect(client.pushes.last.map((x) => x.rowId), [
      't1',
    ], reason: 'the tasks are no longer stuck behind the photo');
  });

  test('signing in to a server without photos pushes no photo rows', () async {
    await syncedPicture('https://nemo.test|ben');
    await db.upsertList(list('l1', testClock('a').now().toString()));
    // Left over from the server this device talked to before.
    await KvStore(db).set(KvKeys.serverPhotos, 'true');
    client
      ..photos = false
      ..rejectPhotoChanges = true;
    final c = await container();

    await c.read(syncEngineProvider.notifier).onSignedIn();

    expect(client.pushedPhotoHashes, isEmpty);
    expect(
      client.pushes.expand((p) => p).map((x) => x.rowId),
      containsAll(['l1', 't1']),
    );
    expect(c.read(syncEngineProvider).status, SyncStatus.idle);
  });

  test('an upload the server failed is tried again with the backoff', () async {
    final c = await container(retry: fastRetry);
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;
    client.blobFailures[photo.sha256] = const ApiError(500, 'internal');

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(client.uploaded, isEmpty);
    final state = c.read(syncEngineProvider);
    expect(state.status, SyncStatus.idle, reason: 'the tasks synced fine');
    expect(state.error, isNull);
    expect(client.calls, 1);

    // Nothing else asks for a sync: no edit, no resume, no event.
    client.blobFailures.clear();
    await eventually(() => client.pushedPhotoHashes.isNotEmpty);
    expect(client.uploaded, [photo.sha256]);
    expect(client.pushedPhotoHashes, [photo.sha256]);
  });

  test('a picture too large to store is not retried', () async {
    final c = await container(retry: fastRetry);
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;
    client.blobFailures[photo.sha256] = const ApiError(413, 'blob_too_large');

    await c.read(syncEngineProvider.notifier).syncNow();
    await Future<void>.delayed(noRetryWindow);

    expect(client.calls, 1, reason: 'asking again gets the same answer');
  });

  test('a server without picture routes is not polled for them', () async {
    const hash =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    client.responses.add(pulledPhoto(hash));
    final c = await container(
      retry: fastRetry,
      extra: [photoDownloadEagerProvider.overrideWithValue(true)],
    );

    // The fake answers 404 for bytes it does not hold, as an old server
    // with no blob routes would.
    await c.read(syncEngineProvider.notifier).syncNow();
    await Future<void>.delayed(noRetryWindow);

    expect(client.downloaded, [hash], reason: 'asked once, not again');
    expect(client.calls, 1);
  });

  test('a download the server failed is tried again', () async {
    const hash =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    client.responses.add(pulledPhoto(hash));
    client.blobs[hash] = Uint8List.fromList([1, 2]);
    client.blobFailures[hash] = const ApiError(503, 'unavailable');
    final c = await container(
      retry: fastRetry,
      extra: [photoDownloadEagerProvider.overrideWithValue(true)],
    );

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(await db.missingBlobHashes(), [hash]);

    client.blobFailures.clear();
    await eventually(() async => await store.get(hash) != null);
    expect(await store.get(hash), [1, 2]);
  });

  test('a photo row that cannot be uploaded yet is held back', () async {
    final c = await container();
    client.failWith = const ApiError(507, 'quota_exceeded');
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    await photos().add(PhotoParent.task, 't1', smallJpeg());

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(
      client.pushes.expand((c) => c).whereType<SyncChangePhoto>(),
      isEmpty,
    );
    expect(await db.pendingBlobs(), hasLength(1));
  });

  test('blobs move two at a time', () async {
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final repo = photos();
    for (final width in [10, 20, 30, 40]) {
      await repo.add(PhotoParent.task, 't1', smallJpeg(width: width));
    }

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploaded, hasLength(4));
    expect(client.maxBlobsInFlight, 2);
  });

  test('one picture failing on this device does not fail the sync', () async {
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    addTearDown(() => debugPrint = print);
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final repo = photos();
    final broken = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 10),
    ))!;
    final fine = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 30),
    ))!;
    client.blobFailures[broken.sha256] = const FileSystemException(
      'No space left on device',
    );
    client.responses.add(
      SyncResponse(
        cursor: 3,
        serverHlc: serverHlc,
        changes: [SyncChange.task(task('t2', serverHlc))],
      ),
    );

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploaded, [fine.sha256]);
    expect(
      client.pushes
          .expand((c) => c)
          .whereType<SyncChangePhoto>()
          .map((c) => c.row.id),
      [fine.id],
    );
    expect(await db.taskById('t2'), isNotNull, reason: 'the pull still ran');
    expect((await db.pendingBlobs()).single.sha256, broken.sha256);
    final state = c.read(syncEngineProvider);
    expect(state.status, SyncStatus.idle);
    expect(state.error, isNull);
    expect(logged.join('\n'), contains('No space left on device'));
  });

  test('a refused picture is reported until one gets through', () async {
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;
    client.blobFailures[photo.sha256] = const ApiError(507, 'quota_exceeded');

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).photoError, 'quota_exceeded');
    expect(c.read(syncEngineProvider).error, isNull);

    await c.read(syncEngineProvider.notifier).syncNow();
    expect(
      c.read(syncEngineProvider).photoError,
      'quota_exceeded',
      reason: 'a refusal that has not changed is not wiped by the next sync',
    );

    client.blobFailures.clear();
    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).photoError, isNull);
  });

  test(
    'bytes may be evicted once, and only once, the server has them',
    () async {
      store = MemoryPhotoStore(maxEntries: 1);
      final c = await container();
      await db.upsertTask(task('t1', testClock('a').now().toString()));
      final photo = (await photos().add(PhotoParent.task, 't1', smallJpeg()))!;
      Future<void> crowd() async {
        for (var i = 0; i < 3; i++) {
          await store.put('filler$i', Uint8List.fromList([i]));
        }
      }

      client.blobFailures[photo.sha256] = const ApiError(0, 'network');
      await c.read(syncEngineProvider.notifier).syncNow();
      await crowd();
      expect(await store.get(photo.sha256), isNotNull);

      client.blobFailures.clear();
      await c.read(syncEngineProvider.notifier).syncNow();
      await crowd();
      expect(await store.get(photo.sha256), isNull);
    },
  );

  test(
    'a pulled photo has its bytes fetched where downloads are eager',
    () async {
      const hash =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      client.responses.add(pulledPhoto(hash));
      client.blobs[hash] = Uint8List.fromList([4, 5, 6]);
      final c = await container(
        extra: [photoDownloadEagerProvider.overrideWithValue(true)],
      );

      await c.read(syncEngineProvider.notifier).syncNow();

      expect(await store.get(hash), [4, 5, 6]);
      expect(await db.missingBlobHashes(), isEmpty);
    },
  );

  test('a download that fails is left for the next sync', () async {
    const hash =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    client.responses.add(pulledPhoto(hash));
    final c = await container(
      extra: [photoDownloadEagerProvider.overrideWithValue(true)],
    );

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(c.read(syncEngineProvider).status, SyncStatus.idle);
    expect(await db.missingBlobHashes(), [hash]);
  });

  test(
    'where downloads are not eager, nothing is fetched until it is shown',
    () async {
      const hash =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      client.responses.add(pulledPhoto(hash));
      client.blobs[hash] = Uint8List.fromList([7]);
      final c = await container(
        extra: [photoDownloadEagerProvider.overrideWithValue(false)],
      );

      await c.read(syncEngineProvider.notifier).syncNow();

      expect(client.downloaded, isEmpty);
      expect(await db.missingBlobHashes(), [hash]);
    },
  );
}
