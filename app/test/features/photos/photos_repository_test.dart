import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

void main() {
  Uint8List jpeg({int width = 60, int height = 40}) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, 128);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image));
  }

  Future<void> addTask(AppDatabase db, {String id = 't1'}) => db.upsertTask(
    Task(
      id: id,
      listId: 'l1',
      title: 'T',
      sortKey: 'V',
      updatedAt: testClock('a').now().toString(),
    ),
  );

  test('adding a photo stores the bytes and queues the row', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    );
    await addTask(db);

    final photo = (await repo.add('t1', jpeg()))!;

    expect(photo.taskId, 't1');
    expect(photo.width, 60);
    expect(photo.height, 40);
    expect(await store.get(photo.sha256), isNotNull);
    expect((await db.pendingBlobs()).single.sha256, photo.sha256);
    expect(await repo.bytes(photo.sha256), isNotNull);
    expect(await repo.watchByTask('t1').first, [photo]);
    expect(await repo.watchPendingHashes().first, {photo.sha256});
  });

  test('two photos of the same task keep the order they were added', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      MemoryPhotoStore(),
    );
    await addTask(db);

    final first = (await repo.add('t1', jpeg(width: 10, height: 10)))!;
    final second = (await repo.add('t1', jpeg(width: 20, height: 20)))!;

    expect(first.sortKey.compareTo(second.sortKey), lessThan(0));
    expect(await repo.watchCounts().first, {'t1': 2});
  });

  test(
    'deleting tombstones the row and drops bytes nothing else names',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final store = MemoryPhotoStore();
      final repo = PhotosRepository(
        db,
        testClock('a'),
        sequentialIds('p'),
        store,
      );
      await addTask(db);
      final photo = (await repo.add('t1', jpeg()))!;

      await repo.delete(photo.id);

      final stored = await db.photoById(photo.id);
      expect(stored!.isDeleted, isTrue);
      expect(await store.get(photo.sha256), isNull);
      expect(await repo.watchByTask('t1').first, isEmpty);
    },
  );

  test('bytes that are not a picture are refused', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    );
    await addTask(db);

    expect(await repo.add('t1', Uint8List.fromList([1, 2, 3])), isNull);

    // Nothing was written: no store entry, no blob row, no photo row, and
    // so nothing queued to push either.
    expect(await db.pendingBlobs(), isEmpty);
    expect(await repo.watchByTask('t1').first, isEmpty);
    expect((await db.outboxChanges()).whereType<SyncChangePhoto>(), isEmpty);
  });

  test(
    'a photo waits in the outbox until its bytes have been uploaded',
    () async {
      final db = testDatabase();
      addTearDown(db.close);
      final repo = PhotosRepository(
        db,
        testClock('a'),
        sequentialIds('p'),
        MemoryPhotoStore(),
      );
      await addTask(db);

      final photo = (await repo.add('t1', jpeg()))!;

      expect(
        (await db.outboxChanges()).whereType<SyncChangePhoto>(),
        isEmpty,
        reason: 'the server would hold a row whose bytes it cannot serve',
      );

      await db.markBlobSynced(photo.sha256);

      expect(
        (await db.outboxChanges()).whereType<SyncChangePhoto>().single.row.id,
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
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    );
    await addTask(db);

    final photo = (await repo.add('t1', jpeg()))!;
    for (var i = 0; i < 5; i++) {
      await store.put('filler$i', Uint8List.fromList([i]));
    }

    expect(await store.get(photo.sha256), isNotNull);
  });

  test('adding a picture already synced on this device leaves it synced and '
      'immediately pushable', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    );
    await addTask(db);
    final first = (await repo.add('t1', jpeg()))!;
    await db.markBlobSynced(first.sha256);

    final second = (await repo.add('t1', jpeg()))!;

    expect(second.sha256, first.sha256);
    final blob = await db.pendingBlobs();
    expect(blob, isEmpty, reason: 'the blob must stay synced, not revert');
    expect(
      (await db.outboxChanges()).whereType<SyncChangePhoto>().map(
        (c) => c.row.id,
      ),
      containsAll([first.id, second.id]),
    );
  });

  test('deleting one of two photos sharing a hash keeps the bytes until both '
      'are gone', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    );
    await addTask(db);
    final first = (await repo.add('t1', jpeg()))!;
    await db.markBlobSynced(first.sha256);
    final second = (await repo.add('t1', jpeg()))!;

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
