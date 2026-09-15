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
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/settings/data/data_export.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

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
    expect(archive.findFile(DataExport.photoEntry(photo.sha256))!.readBytes(), [
      1,
      2,
      3,
    ]);
  });

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

  test('a zip without the export, or a newer version, is refused', () async {
    final exporter = DataExport(db, testClock('a'), store);
    final empty = ZipEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.string('readme.txt', 'hello')),
    );
    await expectLater(exporter.import(empty), throwsFormatException);

    await seed(db);
    final result = await exporter.export(now: testNow);
    final v3 = exportJson(result.bytes)..['version'] = 3;
    final fresh = testDatabase();
    addTearDown(fresh.close);
    await expectLater(
      DataExport(
        fresh,
        testClock('b'),
        MemoryPhotoStore(),
      ).import(Uint8List.fromList(utf8.encode(jsonEncode(v3)))),
      throwsFormatException,
    );
    expect(await fresh.select(fresh.tasks).get(), isEmpty);
  });
}
