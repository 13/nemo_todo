import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/settings/data/data_export.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

/// Wraps a [MemoryPhotoStore] and throws from [pin] on its [throwOnCall]th
/// call, so an import can be made to fail deterministically partway through
/// its photo loop.
class _ThrowingPinStore implements PhotoStore {
  _ThrowingPinStore(this._inner, {required this.throwOnCall});

  final MemoryPhotoStore _inner;
  final int throwOnCall;
  var _pinCalls = 0;

  @override
  Future<void> put(String sha256, Uint8List bytes) => _inner.put(sha256, bytes);

  @override
  Future<Uint8List?> get(String sha256) => _inner.get(sha256);

  @override
  Future<void> remove(String sha256) => _inner.remove(sha256);

  @override
  Future<void> pin(String sha256) async {
    _pinCalls++;
    if (_pinCalls == throwOnCall) throw StateError('pin failed');
    await _inner.pin(sha256);
  }

  @override
  Future<void> unpin(String sha256) => _inner.unpin(sha256);
}

void main() {
  late AppDatabase db;
  late MemoryPhotoStore store;

  setUp(() {
    db = testDatabase();
    store = MemoryPhotoStore();
  });
  tearDown(() => db.close());

  Future<void> seed(AppDatabase db) async {
    final lists = ListsRepository(db, testClock('a'), sequentialIds('l'));
    final tasks = TasksRepository(
      db,
      testClock('a'),
      sequentialIds('t'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    final subtasks = SubtasksRepository(db, testClock('a'), sequentialIds('s'));
    final inbox = await lists.ensureInbox();
    final work = await lists.create(name: 'Work');
    final report = await tasks.create(listId: work.id, title: 'Report');
    await tasks.create(listId: inbox.id, title: 'Milk');
    await subtasks.add(report.id, 'Draft');
    final gone = await tasks.create(listId: work.id, title: 'Deleted one');
    await tasks.delete(gone.id);
  }

  Map<String, dynamic> exportJson(Uint8List zip) => jsonDecode(
    utf8.decode(
      ZipDecoder()
          .decodeBytes(zip)
          .findFile(DataExport.jsonEntry)!
          .readBytes()!,
    ),
  ) as Map<String, dynamic>;

  Future<String> taskId(AppDatabase db, String title) async =>
      (await (db.select(
        db.tasks,
      )..where((t) => t.title.equals(title))).getSingle()).id;

  /// A picture on [taskId] whose bytes this device holds.
  Future<Photo> photoOn(String taskId, List<int> content) async {
    final bytes = Uint8List.fromList(content);
    final hash = sha256.convert(bytes).toString();
    await store.put(hash, bytes);
    await db.rememberBlob(hash, byteSize: bytes.length, state: 'synced');
    final photo = Photo(
      id: 'photo-${hash.substring(0, 8)}',
      taskId: taskId,
      sha256: hash,
      byteSize: bytes.length,
      width: 1,
      height: 1,
      sortKey: 'V',
      updatedAt: testClock('a').now().toString(),
    );
    await db.upsertPhoto(photo);
    return photo;
  }

  test('exports what is alive, and a fresh device takes all of it', () async {
    await seed(db);
    final bytes = (await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow)).bytes;
    final json = exportJson(bytes);
    expect(json['format'], 'nemo-export');
    expect(json['version'], 2);
    expect(json['photos'], isEmpty);
    expect(json['lists'], hasLength(2));
    expect(
      [for (final t in json['tasks'] as List) (t as Map)['title']],
      ['Report', 'Milk'],
    );
    expect(json['subtasks'], hasLength(1));

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final added = await DataExport(
      fresh,
      testClock('b'),
      MemoryPhotoStore(),
    ).import(bytes);
    expect(added, 5);
    expect(await fresh.select(fresh.tasks).get(), hasLength(2));
    expect(await fresh.outboxCount(), 5, reason: 'queued for the server');
  });

  test('importing twice adds nothing the second time', () async {
    await seed(db);
    final export = DataExport(db, testClock('a'), store);
    final bytes = (await export.export(now: testNow)).bytes;
    expect(await export.import(bytes), 0);
  });

  test('a deleted task comes back, newer than its deletion', () async {
    await seed(db);
    // One clock for the deletion and the import, the way a device has one:
    // two frozen clocks would hand out the same stamp.
    final clock = testClock('a');
    final export = DataExport(db, clock, store);
    final bytes = (await export.export(now: testNow)).bytes;
    final milk = (await db.select(db.tasks).get()).firstWhere(
      (t) => t.title == 'Milk',
    );
    final stamp = clock.now().toString();
    final tombstone = milk.copyWith(deletedAt: stamp, updatedAt: stamp);
    await db.upsertTask(tombstone);

    expect(await export.import(bytes), 1);
    final back = (await db.taskById(milk.id))!;
    expect(back.isDeleted, isFalse);
    expect(back.updatedAt.compareTo(tombstone.updatedAt), greaterThan(0));
  });

  test('anything but an export is refused before a row is written', () async {
    final export = DataExport(db, testClock('a'), store);
    for (final text in [
      'not json',
      '[]',
      '{"format":"something-else","version":1}',
      '{"format":"nemo-export","version":99}',
      '{"format":"nemo-export","version":1,"tasks":[{"id":1}]}',
    ]) {
      await expectLater(
        export.import(Uint8List.fromList(utf8.encode(text))),
        throwsFormatException,
      );
    }
    expect(await db.select(db.lists).get(), isEmpty);

    // A malformed row inside an otherwise real export -- whose photo row
    // and bytes are both genuinely present -- is refused the same way,
    // and the photo is never stored either.
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await export.export(now: testNow);
    final badJson = exportJson(result.bytes);
    ((badJson['tasks'] as List).firstWhere(
      (t) => (t as Map)['title'] == 'Report',
    ) as Map).remove('title');
    final badArchive = Archive()
      ..addFile(ArchiveFile.string(DataExport.jsonEntry, jsonEncode(badJson)));
    for (final file in ZipDecoder().decodeBytes(result.bytes).files) {
      if (file.name.startsWith('photos/')) {
        badArchive.addFile(ArchiveFile.bytes(file.name, file.readBytes()!));
      }
    }
    final freshForBadRow = testDatabase();
    addTearDown(freshForBadRow.close);
    final storeForBadRow = MemoryPhotoStore();
    await expectLater(
      DataExport(
        freshForBadRow,
        testClock('b'),
        storeForBadRow,
      ).import(ZipEncoder().encodeBytes(badArchive)),
      throwsFormatException,
    );
    expect(await freshForBadRow.select(freshForBadRow.tasks).get(), isEmpty);
    expect(await storeForBadRow.get(photo.sha256), isNull);
  });

  test('the export is a zip holding the rows and the pictures', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);

    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);

    expect(result.photosLeftOut, 0);
    final json = exportJson(result.bytes);
    expect(json['version'], 2);
    expect(
      [for (final p in json['photos'] as List) (p as Map)['sha256']],
      [photo.sha256],
    );
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final pictureEntry = archive.findFile(DataExport.photoEntry(photo.sha256))!;
    expect(pictureEntry.readBytes(), [1, 2, 3]);
    expect(
      pictureEntry.compression,
      CompressionType.none,
      reason: 'stored, not deflated again -- pictures barely shrink',
    );
    expect(archive.findFile(DataExport.jsonEntry)!.readBytes(), isNotNull);
  });

  test('the json entry is always first in the export zip', () async {
    await seed(db);
    await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);

    final archive = ZipDecoder().decodeBytes(result.bytes);
    expect(archive.files.first.name, DataExport.jsonEntry);
  });

  test(
    'one picture shared by two photos is stored once, on both rows',
    () async {
      await seed(db);
      final report = await taskId(db, 'Report');
      final milk = await taskId(db, 'Milk');
      final onReport = await photoOn(report, [1, 2, 3]);
      // Same bytes, so the same hash -- built by hand, since `photoOn`
      // derives its id from the hash and would collide with `onReport`.
      final onMilk = Photo(
        id: 'photo-second',
        taskId: milk,
        sha256: onReport.sha256,
        byteSize: onReport.byteSize,
        width: 1,
        height: 1,
        sortKey: 'W',
        updatedAt: testClock('a').now().toString(),
      );
      await db.upsertPhoto(onMilk);

      final result = await DataExport(
        db,
        testClock('a'),
        store,
      ).export(now: testNow);

      expect(
        [for (final f in ZipDecoder().decodeBytes(result.bytes).files) f.name]
            .where((n) => n.startsWith('photos/')),
        [DataExport.photoEntry(onReport.sha256)],
        reason: 'one entry for the shared hash',
      );
      final json = exportJson(result.bytes);
      expect(json['photos'], hasLength(2));

      final fresh = testDatabase();
      addTearDown(fresh.close);
      final freshStore = MemoryPhotoStore();
      final added = await DataExport(
        fresh,
        testClock('b'),
        freshStore,
      ).import(result.bytes);

      expect(added, 7, reason: '5 rows and 2 photo rows');
      expect(await fresh.select(fresh.photos).get(), hasLength(2));
      expect(
        await fresh.select(fresh.blobs).get(),
        hasLength(1),
        reason: 'the bytes are stored once',
      );
      expect(await freshStore.get(onReport.sha256), [1, 2, 3]);
    },
  );

  test('a fresh device gets the photos back, queued for upload', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final freshStore = MemoryPhotoStore();
    final added = await DataExport(
      fresh,
      testClock('b'),
      freshStore,
    ).import(result.bytes);

    expect(added, 6, reason: '5 rows and 1 photo');
    expect(await freshStore.get(photo.sha256), [1, 2, 3]);
    final blob = await (fresh.select(
      fresh.blobs,
    )..where((b) => b.sha256.equals(photo.sha256))).getSingle();
    expect(blob.state, 'pendingUpload');
    expect(await fresh.outboxCount(), 6, reason: 'queued for the server');
    // Pinned: more unpinned pictures than the store keeps do not evict it.
    for (var i = 0; i <= freshStore.maxEntries; i++) {
      await freshStore.put('$i'.padLeft(64, '0'), Uint8List(1));
    }
    expect(await freshStore.get(photo.sha256), isNotNull);

    final again = await DataExport(
      fresh,
      testClock('b'),
      freshStore,
    ).import(result.bytes);
    expect(again, 0, reason: 'importing twice adds nothing');
  });

  test('an import that fails partway cleans up the bytes it put', () async {
    await seed(db);
    final report = await taskId(db, 'Report');
    final milk = await taskId(db, 'Milk');
    // Processed in this order (plain rowid order): `first` succeeds fully,
    // then `preExisting`'s `pin` is the throwing store's second call and
    // fails, aborting the transaction before `second` is ever reached.
    final first = await photoOn(report, [1, 2, 3]);
    final preExisting = await photoOn(milk, [7, 8, 9]);
    await photoOn(report, [4, 5, 6]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final freshStore = MemoryPhotoStore();
    // What the device already held for that hash before this import ever
    // ran -- a synced download, or a photo added earlier.
    await freshStore.put(preExisting.sha256, Uint8List.fromList([7, 8, 9]));
    await fresh.rememberBlob(preExisting.sha256, byteSize: 3, state: 'synced');
    final throwing = _ThrowingPinStore(freshStore, throwOnCall: 2);

    await expectLater(
      DataExport(fresh, testClock('b'), throwing).import(result.bytes),
      throwsA(isA<StateError>()),
    );

    expect(await fresh.select(fresh.photos).get(), isEmpty);
    expect(await fresh.select(fresh.blobs).get(), hasLength(1));
    expect(await freshStore.get(first.sha256), isNull, reason: 'cleaned up');
    expect(await freshStore.get(preExisting.sha256), [
      7,
      8,
      9,
    ], reason: 'a row already existed for it, so it was left alone');
  });

  test('a photo whose bytes are not here is left out and counted', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    await store.remove(photo.sha256);

    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);

    expect(result.photosLeftOut, 1);
    expect(exportJson(result.bytes)['photos'], isEmpty);
    expect(
      ZipDecoder()
          .decodeBytes(result.bytes)
          .findFile(DataExport.photoEntry(photo.sha256)),
      isNull,
    );
  });

  test('an old json export still imports', () async {
    await seed(db);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);
    final v1 = exportJson(result.bytes)
      ..['version'] = 1
      ..remove('photos');

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final added = await DataExport(
      fresh,
      testClock('b'),
      MemoryPhotoStore(),
    ).import(Uint8List.fromList(utf8.encode(jsonEncode(v1))));

    expect(added, 5);
  });

  test('a picture that does not match its hash is skipped', () async {
    await seed(db);
    await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);
    final tampered = Archive();
    for (final file in ZipDecoder().decodeBytes(result.bytes).files) {
      tampered.addFile(
        ArchiveFile.bytes(
          file.name,
          file.name.startsWith('photos/') ? [9, 9, 9] : file.readBytes()!,
        ),
      );
    }

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final added = await DataExport(
      fresh,
      testClock('b'),
      MemoryPhotoStore(),
    ).import(ZipEncoder().encodeBytes(tampered));

    expect(added, 5, reason: 'the rows, not the photo');
    expect(await fresh.select(fresh.photos).get(), isEmpty);
  });

  test(
    'an untracked entry under photos/ does not stop the real photo',
    () async {
      await seed(db);
      final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
      final result = await DataExport(
        db,
        testClock('a'),
        store,
      ).export(now: testNow);
      final withExtra = Archive();
      for (final file in ZipDecoder().decodeBytes(result.bytes).files) {
        withExtra.addFile(ArchiveFile.bytes(file.name, file.readBytes()!));
      }
      // No row names this hash -- it should simply be ignored, not read.
      withExtra.addFile(
        ArchiveFile.bytes(DataExport.photoEntry('no-such-hash'), [0]),
      );

      final fresh = testDatabase();
      addTearDown(fresh.close);
      final freshStore = MemoryPhotoStore();
      final added = await DataExport(
        fresh,
        testClock('b'),
        freshStore,
      ).import(ZipEncoder().encodeBytes(withExtra));

      expect(added, 6, reason: '5 rows and the real photo');
      expect(await freshStore.get(photo.sha256), [1, 2, 3]);
    },
  );

  test('a photo of a task the file does not hold is not imported', () async {
    await seed(db);
    await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);
    final json = exportJson(result.bytes);
    ((json['photos'] as List).single as Map<String, dynamic>)['task_id'] =
        'no-such-task';
    final original = ZipDecoder().decodeBytes(result.bytes);
    final edited = Archive()
      ..addFile(ArchiveFile.string(DataExport.jsonEntry, jsonEncode(json)));
    for (final file in original.files) {
      if (file.name.startsWith('photos/')) {
        edited.addFile(ArchiveFile.bytes(file.name, file.readBytes()!));
      }
    }

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final added = await DataExport(
      fresh,
      testClock('b'),
      MemoryPhotoStore(),
    ).import(ZipEncoder().encodeBytes(edited));

    expect(added, 5);
    expect(await fresh.select(fresh.photos).get(), isEmpty);
  });

  test('a photo on a task deleted here, and missing from the file, is not '
      'imported', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(
      db,
      testClock('a'),
      store,
    ).export(now: testNow);
    final json = exportJson(result.bytes);
    // As if the file were an older snapshot from before "Report" existed.
    (json['tasks'] as List).removeWhere((t) => (t as Map)['title'] == 'Report');
    final original = ZipDecoder().decodeBytes(result.bytes);
    final edited = Archive()
      ..addFile(ArchiveFile.string(DataExport.jsonEntry, jsonEncode(json)));
    for (final file in original.files) {
      if (file.name.startsWith('photos/')) {
        edited.addFile(ArchiveFile.bytes(file.name, file.readBytes()!));
      }
    }

    final fresh = testDatabase();
    addTearDown(fresh.close);
    // The destination already has this task -- deleted.
    await seed(fresh);
    final freshClock = testClock('b');
    final stamp = freshClock.now().toString();
    final report = (await fresh.taskById(await taskId(fresh, 'Report')))!;
    await fresh.upsertTask(report.copyWith(deletedAt: stamp, updatedAt: stamp));

    final freshStore = MemoryPhotoStore();
    final added = await DataExport(
      fresh,
      freshClock,
      freshStore,
    ).import(ZipEncoder().encodeBytes(edited));

    expect(added, 0, reason: 'the lists, tasks and subtasks are already here');
    expect(await fresh.select(fresh.photos).get(), isEmpty);
    expect(await freshStore.get(photo.sha256), isNull);
  });

  test('a zip without the export, or a newer version, is refused', () async {
    final exporter = DataExport(db, testClock('a'), store);
    // No row could ever name this hash -- there is no json entry at all --
    // but the entry still guards against a photo being stored before the
    // json is even found.
    final emptyHash = sha256.convert([1, 2, 3]).toString();
    final empty = ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string('readme.txt', 'hello'))
        ..addFile(
          ArchiveFile.bytes(DataExport.photoEntry(emptyHash), [1, 2, 3]),
        ),
    );
    final freshForEmpty = testDatabase();
    addTearDown(freshForEmpty.close);
    final storeForEmpty = MemoryPhotoStore();
    await expectLater(
      DataExport(freshForEmpty, testClock('b'), storeForEmpty).import(empty),
      throwsFormatException,
    );
    expect(await storeForEmpty.get(emptyHash), isNull);

    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [4, 5, 6]);
    final result = await exporter.export(now: testNow);

    // Version 3, inside a real export whose photo row and bytes are both
    // genuinely present -- refused before either is stored.
    final v3Json = exportJson(result.bytes)..['version'] = 3;
    final v3Archive = Archive()
      ..addFile(ArchiveFile.string(DataExport.jsonEntry, jsonEncode(v3Json)));
    for (final file in ZipDecoder().decodeBytes(result.bytes).files) {
      if (file.name.startsWith('photos/')) {
        v3Archive.addFile(ArchiveFile.bytes(file.name, file.readBytes()!));
      }
    }
    final freshForV3 = testDatabase();
    addTearDown(freshForV3.close);
    final storeForV3 = MemoryPhotoStore();
    await expectLater(
      DataExport(
        freshForV3,
        testClock('b'),
        storeForV3,
      ).import(ZipEncoder().encodeBytes(v3Archive)),
      throwsFormatException,
    );
    expect(await freshForV3.select(freshForV3.tasks).get(), isEmpty);
    expect(await storeForV3.get(photo.sha256), isNull);
  });
}
