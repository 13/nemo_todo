# Photos in Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export writes a zip with the JSON and the photo bytes, and import restores photos from it while still reading old `.json` exports.

**Architecture:** `DataExport` keeps its rows and merge rules; version 2 adds a `photos` list and moves the JSON into a zip entry beside `photos/<sha256>` entries. Import detects a zip by its magic bytes, verifies each picture's hash, and writes store → pin → blob → row inside the existing transaction. The Settings tiles save `.zip`, accept `zip`/`json`, and report photos left out.

**Tech Stack:** Flutter 3.47.2 (via fvm), drift, `archive` 4.3.0, `crypto`, gen-l10n (en/de/it).

Spec: `docs/superpowers/specs/2026-09-15-photos-in-export-design.md`

## Global Constraints

- Format name `nemo-export`, version 2; JSON entry `nemo-export.json`; picture entries `photos/<sha256>`; file name `nemo-<yyyy>-<mm>-<dd>.zip`; mime `application/zip`; open accepts `zip` and `json`.
- Version-1 `.json` exports keep importing; anything newer than version 2, or without `nemo-export.json`, is refused with `FormatException` before any row or byte is written.
- A photo is imported only for a live task, only when not already alive here, and only when its bytes hash (lowercase hex SHA-256) to the row's `sha256`.
- Import order per photo: `PhotoStore.put` → `PhotoStore.pin` → `rememberBlob(state: 'pendingUpload')` → `upsertPhoto` with a fresh stamp and `deletedAt: null`.
- `archive: ^4.3.0` becomes a direct dependency of `app`.
- Flutter is not on PATH: `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"`. Flutter commands from `app/`; `flutter pub get` and git from the repository root. Branch `feat/photos-in-export` from `main`.
- ARB: edit by hand, placeholder metadata only in `app_en.arb`, regenerate with `flutter gen-l10n`, commit generated files.
- `dart format` changed files. Stage by path. Commit messages end with:
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse

---

### Task 1: Zip export and import with photos in DataExport

**Files:**
- Modify: `app/pubspec.yaml` (add `archive`), `pubspec.lock` (root)
- Modify: `app/lib/features/settings/data/data_export.dart`
- Modify: `app/lib/features/settings/ui/data_tiles.dart` (only `dataExportProvider`, so the app still compiles)
- Test: `app/test/features/settings/data_export_test.dart`

**Interfaces:**
- Produces:
  - `class ExportResult { const ExportResult(Uint8List bytes, {required int photosLeftOut}); final Uint8List bytes; final int photosLeftOut; }`
  - `DataExport(AppDatabase db, HlcClock clock, PhotoStore photos, {ReminderScheduler reminders})`
  - `Future<ExportResult> DataExport.export({required DateTime now})`
  - `Future<int> DataExport.import(Uint8List bytes)` — counts lists, tasks, subtasks and photos added
  - `static const DataExport.version = 2`, `static const DataExport.jsonEntry = 'nemo-export.json'`, `static String DataExport.photoEntry(String sha256)`
- Consumes: `PhotoStore` (`app/lib/features/photos/data/photo_store.dart`), `MemoryPhotoStore` (`photo_store_web.dart`), `AppDatabase.photoById`, `rememberBlob`, `upsertPhoto` (`app/lib/core/db/sync_writes.dart`), `photoStoreProvider` (`app/lib/core/providers.dart`).

- [ ] **Step 1: Branch and dependency**

From the repository root on a clean `main`: `git switch -c feat/photos-in-export`.
In `app/pubspec.yaml` `dependencies:`, add `  archive: ^4.3.0` as the first entry (alphabetically before `audioplayers`). Run `flutter pub get` from the root. Expected: `git diff --stat` shows `app/pubspec.yaml` and `pubspec.lock` only; `archive` now `dependency: direct main`.

- [ ] **Step 2: Update the existing tests to the new API and add the photo tests**

In `app/test/features/settings/data_export_test.dart`:

Add imports:

```dart
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo_core/nemo_core.dart';
```

Change the setup to also create a store:

```dart
  late AppDatabase db;
  late MemoryPhotoStore store;

  setUp(() {
    db = testDatabase();
    store = MemoryPhotoStore();
  });
  tearDown(() => db.close());
```

Add these helpers inside `main()` after `seed`:

```dart
  Map<String, dynamic> exportJson(Uint8List zip) =>
      jsonDecode(
            utf8.decode(
              ZipDecoder()
                  .decodeBytes(zip)
                  .findFile(DataExport.jsonEntry)!
                  .readBytes()!,
            ),
          )
          as Map<String, dynamic>;

  Future<String> taskId(AppDatabase db, String title) async => (await (db
          .select(db.tasks)
        ..where((t) => t.title.equals(title))).getSingle()).id;

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
```

Update every existing test to the new signatures:
- `DataExport(<db>, <clock>)` → `DataExport(<db>, <clock>, store)` (for a second, fresh database use `DataExport(fresh, <clock>, MemoryPhotoStore())`).
- `final text = await DataExport(...).export(now: testNow);` → `final bytes = (await DataExport(...).export(now: testNow)).bytes;`, then `jsonDecode(text)` → `exportJson(bytes)` and `.import(text)` → `.import(bytes)`.
- String literals passed to `import` (in "anything but an export is refused...") → `Uint8List.fromList(utf8.encode(<the same string>))`.
- In the first test also expect `json['version'], 2` and `json['photos'], isEmpty`.

Append the new tests:

```dart
  test('the export is a zip holding the rows and the pictures', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);

    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );

    expect(result.photosLeftOut, 0);
    final json = exportJson(result.bytes);
    expect(json['version'], 2);
    expect([
      for (final p in json['photos'] as List) (p as Map)['sha256'],
    ], [photo.sha256]);
    final archive = ZipDecoder().decodeBytes(result.bytes);
    expect(
      archive.findFile(DataExport.photoEntry(photo.sha256))!.readBytes(),
      [1, 2, 3],
    );
  });

  test('a fresh device gets the photos back, queued for upload', () async {
    await seed(db);
    final photo = await photoOn(await taskId(db, 'Report'), [1, 2, 3]);
    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );

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

    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );

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
    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );
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
    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );
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
    final result = await DataExport(db, testClock('a'), store).export(
      now: testNow,
    );
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
```

(If the photo JSON key is not `task_id`, check `Photo.toJson` in `packages/nemo_core/lib/src/model/photo.g.dart` and use the real key.)

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/settings/data_export_test.dart`
Expected: FAIL to compile (`DataExport` takes two positional arguments; `ExportResult` undefined).

- [ ] **Step 4: Implement DataExport version 2**

Rewrite `app/lib/features/settings/data/data_export.dart` as follows (keeping the existing doc comments on `import`'s merge rules):

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// What an export produced.
class ExportResult {
  const ExportResult(this.bytes, {required this.photosLeftOut});

  /// The zip to save.
  final Uint8List bytes;

  /// Photos whose bytes this device does not hold -- on the web they are
  /// fetched when shown and not kept -- and so are missing from the file.
  final int photosLeftOut;
}

/// Lists, tasks, subtasks and their photos as a file a person can keep, and
/// back again.
///
/// The file is a zip: the rows as JSON in [jsonEntry], and each picture's
/// bytes under [photoEntry], named by their hash like everywhere else.
class DataExport {
  DataExport(
    this._db,
    this._clock,
    this._photos, {
    this.reminders = const NoopReminderScheduler(),
  });

  static const format = 'nemo-export';

  /// 1 was a bare JSON file without photos; it still imports.
  static const version = 2;
  static const jsonEntry = 'nemo-export.json';
  static String photoEntry(String sha256) => 'photos/$sha256';

  final AppDatabase _db;
  final HlcClock _clock;
  final PhotoStore _photos;
  final ReminderScheduler reminders;

  /// Everything alive on this device, as a zip.
  Future<ExportResult> export({required DateTime now}) async {
    final lists = await (_db.select(
      _db.lists,
    )..where((t) => t.deletedAt.isNull())).get();
    final listIds = {for (final l in lists) l.id};
    final tasks = [
      for (final t in await (_db.select(
        _db.tasks,
      )..where((t) => t.deletedAt.isNull())).get())
        if (listIds.contains(t.listId)) t,
    ];
    final taskIds = {for (final t in tasks) t.id};
    final subtasks = [
      for (final s in await (_db.select(
        _db.subtasks,
      )..where((t) => t.deletedAt.isNull())).get())
        if (taskIds.contains(s.taskId)) s,
    ];
    final photos = <Photo>[];
    final pictures = <String, Uint8List>{};
    var leftOut = 0;
    for (final photo in await (_db.select(
      _db.photos,
    )..where((t) => t.deletedAt.isNull())).get()) {
      if (!taskIds.contains(photo.taskId)) continue;
      final bytes = pictures[photo.sha256] ?? await _photos.get(photo.sha256);
      if (bytes == null) {
        leftOut++;
        continue;
      }
      photos.add(photo);
      pictures[photo.sha256] = bytes;
    }
    final json = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': now.toUtc().toIso8601String(),
      'lists': [for (final l in lists) l.toJson()],
      'tasks': [for (final t in tasks) t.toJson()],
      'subtasks': [for (final s in subtasks) s.toJson()],
      'photos': [for (final p in photos) p.toJson()],
    });
    final archive = Archive()..addFile(ArchiveFile.string(jsonEntry, json));
    for (final entry in pictures.entries) {
      archive.addFile(ArchiveFile.bytes(photoEntry(entry.key), entry.value));
    }
    return ExportResult(
      ZipEncoder().encodeBytes(archive),
      photosLeftOut: leftOut,
    );
  }
```

`import`: change the signature to `Future<int> import(Uint8List bytes) async`, parse with `final parsed = _parse(bytes);`, keep the three existing loops over `parsed.lists`, `parsed.tasks`, `parsed.subtasks` unchanged, and add after the subtasks loop, inside the same transaction:

```dart
      for (final photo in parsed.photos) {
        if (!_live(await _db.taskById(photo.taskId))) continue;
        if (_live(await _db.photoById(photo.id))) continue;
        final bytes = parsed.pictures[photo.sha256];
        // A picture that is missing, or is not what its row says it is, is
        // left out rather than restored as a broken image.
        if (bytes == null || sha256.convert(bytes).toString() != photo.sha256) {
          continue;
        }
        // The same order adding a photo uses: bytes known and protected
        // before the row, so a sync never sends the row ahead of them.
        await _photos.put(photo.sha256, bytes);
        await _photos.pin(photo.sha256);
        await _db.rememberBlob(
          photo.sha256,
          byteSize: bytes.length,
          state: 'pendingUpload',
        );
        await _db.upsertPhoto(
          photo.copyWith(updatedAt: _stamp(), deletedAt: null),
        );
        added++;
      }
```

Replace `_parse` with:

```dart
  static _Parsed _parse(Uint8List bytes) {
    try {
      final String text;
      final pictures = <String, Uint8List>{};
      if (_isZip(bytes)) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final json = archive.findFile(jsonEntry)?.readBytes();
        if (json == null) throw const FormatException('not a nemo export');
        text = utf8.decode(json);
        const prefix = 'photos/';
        for (final file in archive.files) {
          if (!file.name.startsWith(prefix) || file.name.endsWith('/')) {
            continue;
          }
          final data = file.readBytes();
          if (data != null) pictures[file.name.substring(prefix.length)] = data;
        }
      } else {
        text = utf8.decode(bytes);
      }
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic> ||
          json['format'] != format ||
          json['version'] is! int ||
          (json['version'] as int) > version) {
        throw const FormatException('not a nemo export');
      }
      List<Map<String, dynamic>> rows(String key) => [
        for (final row in json[key] as List<dynamic>? ?? const [])
          row as Map<String, dynamic>,
      ];
      return (
        lists: [for (final r in rows('lists')) TaskList.fromJson(r)],
        tasks: [for (final r in rows('tasks')) Task.fromJson(r)],
        subtasks: [for (final r in rows('subtasks')) Subtask.fromJson(r)],
        photos: [for (final r in rows('photos')) Photo.fromJson(r)],
        pictures: pictures,
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      // A cast or a missing field in a row: the file is not what it claims.
      throw FormatException('not a nemo export: $e');
    }
  }

  /// A zip file starts with the local file header signature `PK\x03\x04`.
  static bool _isZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

typedef _Parsed = ({
  List<TaskList> lists,
  List<Task> tasks,
  List<Subtask> subtasks,
  List<Photo> photos,
  Map<String, Uint8List> pictures,
});
```

(`utf8.decode` of non-UTF-8 garbage throws `FormatException`, which is rethrown: refused as before.)

In `app/lib/features/settings/ui/data_tiles.dart`, change only the provider for now:

```dart
final dataExportProvider = Provider<DataExport>(
  (ref) => DataExport(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(photoStoreProvider),
    reminders: ref.watch(reminderSchedulerProvider),
  ),
);
```

and, so it compiles until Task 2, in `_export` use `(await ref.read(dataExportProvider).export(now: now)).bytes` in place of `utf8.encode(text)`, and in `_import` pass `bytes` directly to `import(...)`.

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/settings/data_export_test.dart
flutter analyze
```

Expected: all pass; `No issues found!`. (`data_tiles_test.dart` may fail on the file name until Task 2; that is expected here — do not commit it changed yet.)

- [ ] **Step 6: Commit**

```bash
dart format app/lib/features/settings/data/data_export.dart app/lib/features/settings/ui/data_tiles.dart app/test/features/settings/data_export_test.dart
git add app/pubspec.yaml pubspec.lock app/lib/features/settings/data/data_export.dart app/lib/features/settings/ui/data_tiles.dart app/test/features/settings/data_export_test.dart
git commit -m "feat(app): put photos in the export zip and restore them on import

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```

Note: this commit is allowed only if `data_tiles_test.dart` still passes. If it fails on the `.json` name, fold Task 2 Steps 1-2 (name and mime) into this commit instead of leaving a red test.

---

### Task 2: Settings saves a zip and says when photos were left out

**Files:**
- Modify: `app/lib/features/settings/ui/data_tiles.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ regenerated `app_localizations*.dart`)
- Modify: `docs/backlog.md`, `CHANGELOG.md`
- Test: `app/test/features/settings/data_tiles_test.dart`

**Interfaces:**
- Consumes: `ExportResult`, `DataExport.import(Uint8List)` (Task 1).
- Produces: string `settingsExportedWithoutPhotos(int count)`.

- [ ] **Step 1: Strings**

`app_en.arb`: replace the `settingsExportHint` value with `"Lists, tasks, subtasks and photos as a zip file."`, and add before the final `}`:

```json
  "settingsExportedWithoutPhotos": "{count, plural, =1{Tasks exported. 1 photo is not on this device and was left out.} other{Tasks exported. {count} photos are not on this device and were left out.}}",
  "@settingsExportedWithoutPhotos": {
    "placeholders": {"count": {"type": "int"}}
  }
```

`app_de.arb`: `settingsExportHint` → `"Listen, Aufgaben, Unteraufgaben und Fotos als ZIP-Datei."`; add
`"settingsExportedWithoutPhotos": "{count, plural, =1{Aufgaben exportiert. 1 Foto ist nicht auf diesem Gerät und fehlt.} other{Aufgaben exportiert. {count} Fotos sind nicht auf diesem Gerät und fehlen.}}"`

`app_it.arb`: `settingsExportHint` → `"Liste, attività, sottoattività e foto in un file ZIP."`; add
`"settingsExportedWithoutPhotos": "{count, plural, =1{Attività esportate. 1 foto non è su questo dispositivo ed è stata esclusa.} other{Attività esportate. {count} foto non sono su questo dispositivo e sono state escluse.}}"`

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tile tests**

In `app/test/features/settings/data_tiles_test.dart`, add imports `package:archive/archive.dart`, `package:nemo/core/db/sync_writes.dart`, `package:nemo_core/nemo_core.dart`, and replace the first test with:

```dart
  appTest('export saves a dated zip holding the tasks', (tester) async {
    await pump(tester);
    await tap(tester, 'export-data');

    final bytes = files.saved['nemo-2026-09-07.zip'];
    expect(bytes, isNotNull);
    final json = ZipDecoder()
        .decodeBytes(bytes!)
        .findFile('nemo-export.json')!
        .readBytes()!;
    expect(utf8.decode(json), contains('Water the plants'));
    expect(find.text('Tasks exported.'), findsOneWidget);
  });

  appTest('export says when photos were left out', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: [dataFilesProvider.overrideWithValue(files)],
      seed: (db, inbox) async {
        final task = await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(listId: inbox.id, title: 'Water the plants');
        // A photo row whose bytes this device never had.
        await db.upsertPhoto(
          Photo(
            id: 'p1',
            taskId: task.id,
            sha256: 'a' * 64,
            byteSize: 3,
            width: 1,
            height: 1,
            sortKey: 'V',
            updatedAt: testClock('s').now().toString(),
          ),
        );
      },
    );
    await tap(tester, 'export-data');

    expect(
      find.text(
        'Tasks exported. 1 photo is not on this device and was left out.',
      ),
      findsOneWidget,
    );
  });
```

(`'a' * 64` is valid Dart: `String * int` repeats the string.)

Run: `flutter test test/features/settings/data_tiles_test.dart`
Expected: FAIL (file saved as `.json`; no photos message).

- [ ] **Step 3: Implement the tiles**

In `data_tiles.dart`:
- `PickerDataFiles.save`: `mimeType: 'application/zip'`.
- `PickerDataFiles.open`: `allowedExtensions: const ['zip', 'json']`.
- `_export`:

```dart
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(nowProvider)();
    final result = await ref.read(dataExportProvider).export(now: now);
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'nemo-${now.year}-${two(now.month)}-${two(now.day)}.zip';
    final saved = await ref.read(dataFilesProvider).save(name, result.bytes);
    if (!saved) return;
    _tell(
      messenger,
      result.photosLeftOut == 0
          ? l.settingsExported
          : l.settingsExportedWithoutPhotos(result.photosLeftOut),
    );
  }
```

- `_import`: `.import(bytes)` (no `utf8.decode`). Remove the now-unused `dart:convert` import if analyze reports it.

- [ ] **Step 4: Docs**

- `docs/backlog.md`: delete the whole `## Photos in an export` section (its heading and the three bold paragraphs), leaving the intro and the `## Password reset ...` section.
- `CHANGELOG.md`: if there is no `## Unreleased` heading above the newest version heading, add one directly above it (with a blank line after). Under it, add (creating `### Added` if absent):

```markdown
- Exporting from Settings now includes the photos: the file is a zip with
  the pictures beside the tasks, and importing it brings them back. Exports
  made before still import.
```

- [ ] **Step 5: Verify**

```bash
flutter test test/features/settings/ test/l10n/translations_test.dart
flutter test --exclude-tags design
flutter analyze
dart format --output=none --set-exit-if-changed lib test
```

Expected: all pass; `No issues found!`; format exit 0.

- [ ] **Step 6: Commit**

```bash
dart format app/lib/features/settings/ui/data_tiles.dart app/test/features/settings/data_tiles_test.dart
git add app/lib/features/settings/ui/data_tiles.dart app/test/features/settings/data_tiles_test.dart app/lib/l10n/app_en.arb app/lib/l10n/app_de.arb app/lib/l10n/app_it.arb app/lib/l10n/app_localizations.dart app/lib/l10n/app_localizations_en.dart app/lib/l10n/app_localizations_de.dart app/lib/l10n/app_localizations_it.dart docs/backlog.md CHANGELOG.md
git commit -m "feat(app): export photos as a zip from Settings

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse"
```
