import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/test_db.dart';

void main() {
  Future<void> addTask(AppDatabase db, {String id = 't1'}) => db.upsertTask(
    Task(
      id: id,
      listId: 'l1',
      title: 'T',
      sortKey: 'V',
      updatedAt: testClock('a').now().toString(),
    ),
  );

  // These run under plain `test()`, so the default off-isolate processor
  // (a real isolate) would work here too -- but spinning one up per case
  // adds real seconds across this file, so every repository test opts
  // into the synchronous processor for speed instead.
  PhotosRepository newRepo(AppDatabase db, PhotoStore store) =>
      PhotosRepository(
        db,
        testClock('a'),
        sequentialIds('p'),
        store,
        process: (raw) async => processPhoto(raw),
      );

  test('adding a photo stores the bytes and queues the row', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = newRepo(db, store);
    await addTask(db);

    final photo = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;

    expect(photo.parentId, 't1');
    expect(photo.width, 60);
    expect(photo.height, 40);
    expect(await store.get(photo.sha256), isNotNull);
    expect((await db.pendingBlobs()).single.sha256, photo.sha256);
    expect(await repo.bytes(photo.sha256), isNotNull);
    expect(await repo.watchByParent(PhotoParent.task, 't1').first, [photo]);
    expect(await repo.watchPendingHashes().first, {photo.sha256});
  });

  test('two photos of the same task keep the order they were added', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = newRepo(db, MemoryPhotoStore());
    await addTask(db);

    final first = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 10, height: 10),
    ))!;
    final second = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(height: 20),
    ))!;

    expect(first.sortKey.compareTo(second.sortKey), lessThan(0));
    expect(await repo.watchCounts().first, {'t1': 2});
  });

  test(
    'deleting tombstones the row and drops bytes nothing else names',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final store = MemoryPhotoStore();
      final repo = newRepo(db, store);
      await addTask(db);
      final photo = (await repo.add(
        PhotoParent.task,
        't1',
        smallJpeg(width: 60, height: 40),
      ))!;

      await repo.delete(photo.id);

      final stored = await db.photoById(photo.id);
      expect(stored!.isDeleted, isTrue);
      expect(await store.get(photo.sha256), isNull);
      expect(await repo.watchByParent(PhotoParent.task, 't1').first, isEmpty);
    },
  );

  test('bytes that are not a picture are refused', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = newRepo(db, store);
    await addTask(db);

    expect(
      await repo.add(PhotoParent.task, 't1', Uint8List.fromList([1, 2, 3])),
      isNull,
    );

    // Nothing was written: no store entry, no blob row, no photo row, and
    // so nothing queued to push either.
    expect(await db.pendingBlobs(), isEmpty);
    expect(await repo.watchByParent(PhotoParent.task, 't1').first, isEmpty);
    expect(
      (await db.outboxChanges(
        includePhotos: true,
        includeNotes: true,
      )).whereType<SyncChangePhoto>(),
      isEmpty,
    );
  });

  test(
    'a photo waits in the outbox until its bytes have been uploaded',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final repo = newRepo(db, MemoryPhotoStore());
      await addTask(db);

      final photo = (await repo.add(
        PhotoParent.task,
        't1',
        smallJpeg(width: 60, height: 40),
      ))!;

      expect(
        (await db.outboxChanges(
          includePhotos: true,
          includeNotes: true,
        )).whereType<SyncChangePhoto>(),
        isEmpty,
        reason: 'the server would hold a row whose bytes it cannot serve',
      );

      await db.markBlobSynced(photo.sha256);

      expect(
        (await db.outboxChanges(
          includePhotos: true,
          includeNotes: true,
        )).whereType<SyncChangePhoto>().single.row.id,
        photo.id,
      );
    },
  );

  test('a photo added on the web is pinned so it cannot be evicted', () async {
    final db = testDatabase();
    addTearDown(db.close);
    // A bound of one: any put that is not exempt would otherwise knock the
    // added photo's bytes straight out.
    final store = MemoryPhotoStore(maxEntries: 1);
    final repo = newRepo(db, store);
    await addTask(db);

    final photo = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;
    for (var i = 0; i < 5; i++) {
      await store.put('filler$i', Uint8List.fromList([i]));
    }

    expect(await store.get(photo.sha256), isNotNull);
  });

  test('adding a picture this device thinks is synced uploads it again, and '
      'holds the row until it has', () async {
    final db = testDatabase();
    addTearDown(db.close);
    // A bound of one, so an unpinned copy would be evicted by the filler.
    final store = MemoryPhotoStore(maxEntries: 1);
    final repo = newRepo(db, store);
    await addTask(db);
    final first = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;
    await db.markBlobSynced(first.sha256);
    await store.unpin(first.sha256);

    final second = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;

    expect(second.sha256, first.sha256);
    // "Synced" is only what the server said last time: it may have swept
    // the bytes since, and a row that reaches it without them is a broken
    // picture on every other device.
    expect(
      (await db.pendingBlobs()).single.sha256,
      first.sha256,
      reason: 'the blob goes back to waiting for an upload',
    );
    await store.put('filler', Uint8List.fromList([1]));
    expect(
      await store.get(first.sha256),
      isNotNull,
      reason: 'pinned again until that upload lands',
    );
    Future<List<String>> pushable() async => (await db.outboxChanges(
      includePhotos: true,
      includeNotes: true,
    )).whereType<SyncChangePhoto>().map((c) => c.row.id).toList();
    expect(await pushable(), isEmpty, reason: 'both rows name those bytes');

    await db.markBlobSynced(first.sha256);
    expect(await pushable(), containsAll([first.id, second.id]));
  });

  test('deleting one of two photos sharing a hash keeps the bytes until both '
      'are gone', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = newRepo(db, store);
    await addTask(db);
    final first = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;
    await db.markBlobSynced(first.sha256);
    final second = (await repo.add(
      PhotoParent.task,
      't1',
      smallJpeg(width: 60, height: 40),
    ))!;

    await repo.delete(first.id);

    expect(
      await store.get(first.sha256),
      isNotNull,
      reason: 'the second photo still names this hash',
    );

    await repo.delete(second.id);

    expect(await store.get(first.sha256), isNull);
  });
}
