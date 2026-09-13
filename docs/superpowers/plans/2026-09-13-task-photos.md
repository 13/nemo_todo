# Photos on Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a task carry photos taken in the app or picked from the device, syncing them through the nemo server to every device and every member of a shared list.

**Architecture:** A photo is split in two. The metadata is a fourth synced row (`photo`) travelling on the existing `/sync` endpoint with the same last-write-wins merge as tasks and subtasks, carrying the SHA-256 of its bytes rather than the bytes. The bytes move over a new content-addressed blob channel (`POST`/`GET /api/v1/blobs/<sha256>`), stored as files on the server with a metadata row in SQLite. Clients upload bytes before pushing the row, so a row on the server always has bytes behind it.

**Tech Stack:** Dart 3.13, Flutter, drift (SQLite on both sides), freezed + json_serializable, riverpod, shelf + shelf_router, dio, `image_picker` and `image` (new app dependencies).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-13-task-photos-design.md`. Read it before Task 1.
- Row classes live in `packages/nemo_core`; the identical drift table is declared **twice**, in `server/lib/src/db/sync_tables.dart` and `app/lib/core/db/sync_tables.dart`. Both must match the row class constructor exactly or drift refuses to generate.
- Processed photo: longest edge ≤ 2048 px, JPEG quality 85, re-encoded in every case.
- Server limits: 5 MB per blob (413), 500 MB per account (507), both configurable in `server/lib/src/config.dart`.
- Blob path on the server: `<blobDir>/<sha[0:2]>/<sha[2:4]>/<sha>`.
- Blob state on the device is `pendingUpload` or `synced` — those exact strings.
- Every user-visible string goes through `l10n` in all three locales: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`.
- Generated code is committed. After changing anything a generator owns, run the generator (commands are in each task) — the pre-commit hook rejects a commit whose generated code is stale.
- Analysis is `very_good_analysis`; prefer `const`, trailing commas, and the surrounding comment style (explain *why*, never *what*).
- Commit messages use Conventional Commits (`feat:`, `test:`, `build:`, `docs:`) and end with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku
```

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `packages/nemo_core/lib/src/model/photo.dart` | The `Photo` row class |
| `server/lib/src/blobs/blob_store.dart` | Bytes on disk: paths, read, write, delete |
| `server/lib/src/blobs/blob_service.dart` | Upload/download policy: hash check, quota, membership |
| `app/lib/features/photos/data/photo_pipeline.dart` | Pure bytes-to-bytes processing |
| `app/lib/features/photos/data/photo_store.dart` | `PhotoStore` interface + platform selection |
| `app/lib/features/photos/data/photo_store_io.dart` | Files under the app support directory |
| `app/lib/features/photos/data/photo_store_web.dart` | Bounded in-memory cache |
| `app/lib/features/photos/data/photos_repository.dart` | Add, delete, watch photos of a task |
| `app/lib/features/photos/ui/photos_providers.dart` | Riverpod wiring for the above |
| `app/lib/features/photos/ui/photo_thumbnail.dart` | One thumbnail, resolving bytes or a placeholder |
| `app/lib/features/photos/ui/photo_strip.dart` | The strip on the task detail screen |
| `app/lib/features/photos/ui/photo_viewer.dart` | Full-screen pager with delete |

**Modified**

| Path | Change |
|---|---|
| `packages/nemo_core/lib/src/model/sync.dart` | `SyncEntity.photo`, `SyncChange.photo` |
| `packages/nemo_core/lib/nemo_core.dart` | Export the model |
| `server/lib/src/db/sync_tables.dart` | `Photos` table |
| `server/lib/src/db/server_tables.dart` | `Blobs` table |
| `server/lib/src/db/server_database.dart` | Schema 3 → 4 |
| `server/lib/src/sync/sync_log_writer.dart` | `photoById`, `photosOfTask`, `canSeeBlob`, `blobBytesOwnedBy` |
| `server/lib/src/sync/sync_service.dart` | Apply and pull photo rows |
| `server/lib/src/http/handler.dart` | `POST`/`GET /blobs/<sha256>` |
| `server/lib/src/config.dart` | `blobDir`, `maxBlobBytes`, `accountQuotaBytes` |
| `server/lib/src/maintenance/purge_service.dart` | Purge photo rows, sweep orphaned blobs |
| `server/lib/nemo_server.dart` | Export the blob classes |
| `app/lib/core/db/sync_tables.dart` | `Photos` table |
| `app/lib/core/db/app_tables.dart` | `Blobs` table (local state) |
| `app/lib/core/db/app_database.dart` | Schema 2 → 3 |
| `app/lib/core/db/sync_writes.dart` | Photo rows and blob state through the outbox |
| `app/lib/features/sync/data/sync_client.dart` | `uploadBlob`, `downloadBlob` |
| `app/lib/features/sync/ui/sync_engine.dart` | Upload phase before push, download phase after pull |
| `app/lib/core/providers.dart` | `photoDownloadEagerProvider` |
| `app/lib/features/tasks/ui/task_detail_screen.dart` | The photo strip |
| `app/lib/core/widgets/task_tile.dart` | Thumbnail and count |
| `app/pubspec.yaml` | `image_picker`, `image` |

---

### Task 1: The `Photo` row in nemo_core

**Files:**
- Create: `packages/nemo_core/lib/src/model/photo.dart`
- Modify: `packages/nemo_core/lib/src/model/sync.dart`
- Modify: `packages/nemo_core/lib/nemo_core.dart`
- Test: `packages/nemo_core/test/sync_dto_test.dart`

**Interfaces:**
- Consumes: `SyncRow` (`id`, `updatedAt`, `deletedAt`), `incomingWins(SyncRow?, SyncRow)`.
- Produces: `Photo({required String id, required String taskId, required String sha256, required int byteSize, required int width, required int height, required String sortKey, required String updatedAt, String? deletedAt})` with `Photo.fromJson`, `toJson`, `copyWith`, `isDeleted`; `SyncEntity.photo`; `SyncChange.photo(Photo row)` → `SyncChangePhoto`.

- [ ] **Step 1: Write the failing test**

Append to `packages/nemo_core/test/sync_dto_test.dart`, inside the existing `main()`:

```dart
  test('a photo change survives a round trip through JSON', () {
    const photo = Photo(
      id: 'p1',
      taskId: 't1',
      sha256: 'a' * 64,
      byteSize: 4096,
      width: 2048,
      height: 1536,
      sortKey: 'V',
      updatedAt: '2026-09-13T10:00:00.000Z-0000-node',
    );
    final change = SyncChange.photo(photo);
    final json = change.toJson();
    expect(json['type'], 'photo');
    final back = SyncChange.fromJson(json);
    expect(back, change);
    expect(back.entity, SyncEntity.photo);
    expect(back.rowId, 'p1');
    expect(photo.isDeleted, isFalse);
    expect(
      photo.copyWith(deletedAt: photo.updatedAt).isDeleted,
      isTrue,
    );
  });

  test('a photo merges by its stamp like any other row', () {
    const older = Photo(
      id: 'p1',
      taskId: 't1',
      sha256: 'a' * 64,
      byteSize: 10,
      width: 1,
      height: 1,
      sortKey: 'V',
      updatedAt: '2026-09-13T10:00:00.000Z-0000-a',
    );
    final newer = older.copyWith(
      updatedAt: '2026-09-13T10:00:01.000Z-0000-a',
    );
    expect(incomingWins(older, newer), isTrue);
    expect(incomingWins(newer, older), isFalse);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd packages/nemo_core && dart test test/sync_dto_test.dart`
Expected: FAIL — `Undefined name 'Photo'` / `The method 'photo' isn't defined for the type 'SyncChange'`.

- [ ] **Step 3: Write the model**

Create `packages/nemo_core/lib/src/model/photo.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo_core/src/model/sync_row.dart';

part 'photo.freezed.dart';
part 'photo.g.dart';

/// A picture attached to a task.
///
/// The row carries the SHA-256 of the bytes rather than the bytes: the
/// picture itself travels over the blob channel, which needs no merge
/// rules because a hash never names two different images.
@freezed
abstract class Photo with _$Photo implements SyncRow {
  const factory Photo({
    required String id,
    required String taskId,

    /// Lowercase hex SHA-256 of the processed bytes.
    required String sha256,
    required int byteSize,
    required int width,
    required int height,
    required String sortKey,
    required String updatedAt,
    String? deletedAt,
  }) = _Photo;

  const Photo._();

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);

  bool get isDeleted => deletedAt != null;
}
```

- [ ] **Step 4: Add the entity and the union case**

In `packages/nemo_core/lib/src/model/sync.dart`, add the import:

```dart
import 'package:nemo_core/src/model/photo.dart';
```

Extend the enum:

```dart
/// The kinds of rows that travel through the sync endpoint.
enum SyncEntity { list, task, subtask, photo }
```

Add the union case after `SyncChange.subtask`:

```dart
  const factory SyncChange.photo(Photo row) = SyncChangePhoto;
```

Add the arms to both switches:

```dart
  SyncEntity get entity => switch (this) {
    SyncChangeList() => SyncEntity.list,
    SyncChangeTask() => SyncEntity.task,
    SyncChangeSubtask() => SyncEntity.subtask,
    SyncChangePhoto() => SyncEntity.photo,
    SyncChangeRevoke(:final target) => target,
  };

  String get rowId => switch (this) {
    SyncChangeList(:final row) => row.id,
    SyncChangeTask(:final row) => row.id,
    SyncChangeSubtask(:final row) => row.id,
    SyncChangePhoto(:final row) => row.id,
    SyncChangeRevoke(:final id) => id,
  };
```

In `packages/nemo_core/lib/nemo_core.dart`, add the export in alphabetical order (after `merge.dart`):

```dart
export 'src/model/photo.dart';
```

- [ ] **Step 5: Generate and run the test**

Run: `cd packages/nemo_core && dart run build_runner build --delete-conflicting-outputs && dart test`
Expected: PASS, whole suite green.

- [ ] **Step 6: Commit**

```bash
git add packages/nemo_core
git commit -m "feat(core): a photo is a synced row carrying its bytes' hash

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 2: Server schema — `photos` and `blobs`

**Files:**
- Modify: `server/lib/src/db/sync_tables.dart`
- Modify: `server/lib/src/db/server_tables.dart`
- Modify: `server/lib/src/db/server_database.dart`
- Test: `server/test/migration_test.dart`

**Interfaces:**
- Consumes: `Photo` from Task 1.
- Produces: drift tables `photos` (row class `Photo`) and `blobs` (data class `BlobRow`: `sha256`, `byteSize`, `ownerUserId`, `createdAt`); `ServerDatabase.schemaVersion == 4`.

- [ ] **Step 1: Write the failing test**

In `server/test/migration_test.dart`, change the two version literals and extend the index assertion:

```dart
  test('migrates a database from every earlier version', () async {
    for (final from in [1, 2, 3]) {
      final verifier = SchemaVerifier(GeneratedHelper());
      final connection = await verifier.startAt(from);
      final db = ServerDatabase(connection);
      await verifier.migrateAndValidate(db, 4);
      await db.close();
    }
  });

  test('the migrated database has the indexes a fresh one gets', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(1);
    final db = ServerDatabase(connection);
    await verifier.migrateAndValidate(db, 4);
    final indexes =
        (await db
                .customSelect(
                  "select name from sqlite_master where type = 'index'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toList();
    expect(
      indexes,
      containsAll(['list_members_user_id', 'sync_log_row', 'photos_task_id']),
    );
    await db.close();
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd server && dart test test/migration_test.dart`
Expected: FAIL — the verifier has no snapshot for version 4 / `photos_task_id` missing.

- [ ] **Step 3: Add the tables**

Append to `server/lib/src/db/sync_tables.dart`:

```dart
@TableIndex(name: 'photos_task_id', columns: {#taskId})
@UseRowClass(Photo, generateInsertable: true)
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get sortKey => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Append to `server/lib/src/db/server_tables.dart`:

```dart
/// Bytes the server holds, one row per distinct SHA-256. The file itself
/// lives under the blob directory; this row is what makes it findable,
/// countable against a quota, and sweepable once no photo names it.
@DataClassName('BlobRow')
class Blobs extends Table {
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();

  /// Who first uploaded it, and therefore whose quota it counts against.
  TextColumn get ownerUserId => text()();

  /// Epoch milliseconds. A blob is not a synced row and has no HLC.
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sha256};
}
```

- [ ] **Step 4: Register the tables and the migration**

In `server/lib/src/db/server_database.dart`:

```dart
@DriftDatabase(
  tables: [
    Lists,
    Tasks,
    Subtasks,
    Photos,
    Users,
    Sessions,
    ListMembers,
    SyncLog,
    Blobs,
  ],
)
```

```dart
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Indexes are created one by one rather than with createAll(): drift
      // emits index DDL without `if not exists`, so createAll() throws on a
      // database that already holds the tables.
      if (from < 2) {
        await m.create(listMembersUserId);
        await m.create(syncLogRow);
      }
      // Version 3 carries how often a task comes back. The server never
      // reads it; it stores and forwards it like every other column.
      if (from < 3) await m.addColumn(tasks, tasks.repeat);
      // Version 4 carries pictures: the rows that name them, and the
      // bytes the server is holding for them.
      if (from < 4) {
        await m.createTable(photos);
        await m.create(photosTaskId);
        await m.createTable(blobs);
      }
    },
  );
```

- [ ] **Step 5: Generate, dump the schema, and run the test**

Run:

```bash
cd server
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/src/db/server_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated/
dart test test/migration_test.dart test/server_database_test.dart
```

Expected: PASS, and `drift_schemas/drift_schema_v4.json` now exists.

- [ ] **Step 6: Commit**

```bash
git add server
git commit -m "feat(server): tables for photo rows and the bytes behind them

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 3: Syncing photo rows

**Files:**
- Modify: `server/lib/src/sync/sync_log_writer.dart`
- Modify: `server/lib/src/sync/sync_service.dart`
- Test: `server/test/sync_service_test.dart`
- Test: `server/test/support/rows.dart`

**Interfaces:**
- Consumes: `Photos` table (Task 2), `SyncChangePhoto` (Task 1), `logUpsert`, `logRevoke`, `taskById`.
- Produces: `ServerDatabase.photoById(String id)`, `ServerDatabase.photosOfTask(String taskId)`; `/sync` accepts and returns `SyncChange.photo`.

- [ ] **Step 1: Add the fixture**

Append to `server/test/support/rows.dart`:

```dart
Photo photo(String id, String taskId, HlcClock clock, {String? sha}) => Photo(
  id: id,
  taskId: taskId,
  sha256: sha ?? 'a' * 64,
  byteSize: 1024,
  width: 100,
  height: 80,
  sortKey: 'V',
  updatedAt: clock.now().toString(),
);
```

- [ ] **Step 2: Write the failing test**

Append inside `main()` in `server/test/sync_service_test.dart`. The file
already provides `db`, `sync`, `dev`, `user(name)` and `push(userId,
changes)` — use them rather than building a database per test. Add
`import 'package:drift/drift.dart';` at the top if it is not there yet.

```dart
  test('a photo travels with the task it hangs off', () async {
    final ben = await user('ben');
    final anna = await user('anna');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);
    expect((await db.photoById('p1'))!.sha256, 'a' * 64);

    // Anna joins the list; the next push re-logs the photo for her too.
    await db.into(db.listMembers).insert(
      ListMembersCompanion.insert(
        listId: 'l1',
        userId: anna,
        role: MemberRole.editor.name,
      ),
    );
    await push(ben, [SyncChange.photo(photo('p1', 't1', laterClock('dev')))]);

    final pulled = await push(anna, []);
    expect(
      pulled.changes.whereType<SyncChangePhoto>().single.row.id,
      'p1',
    );
  });

  test('a photo on a task you are not a member of is refused', () async {
    final ben = await user('ben');
    final mallory = await user('mallory');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
    ]);

    final refused = await push(mallory, [
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);
    expect(refused.rejected.single.reason, 'forbidden');
    expect(await db.photoById('p1'), isNull);
  });

  test('a photo whose task is unknown is refused', () async {
    final ben = await user('ben');
    final refused = await push(ben, [
      SyncChange.photo(photo('p1', 'nope', dev)),
    ]);
    expect(refused.rejected.single.reason, 'unknown_task');
  });

  test('moving a task to another list carries its photos', () async {
    final ben = await user('ben');
    await push(ben, [
      SyncChange.list(list('l1', dev)),
      SyncChange.list(list('l2', dev)),
      SyncChange.task(task('t1', 'l1', dev)),
      SyncChange.photo(photo('p1', 't1', dev)),
    ]);

    await push(ben, [SyncChange.task(task('t1', 'l2', laterClock('dev')))]);

    final entries = await (db.select(db.syncLog)
          ..where((t) => t.entity.equals('photo')))
        .get();
    expect(
      entries.map((e) => '${e.op}:${e.listId}'),
      containsAll(['revoke:l1', 'upsert:l2']),
    );
  });
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd server && dart test test/sync_service_test.dart`
Expected: FAIL — `photoById` undefined, and the pushed photo is not stored.

- [ ] **Step 4: Add the queries**

In `server/lib/src/sync/sync_log_writer.dart`, beside `subtaskById`:

```dart
  Future<Photo?> photoById(String id) =>
      (select(photos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Photo>> photosOfTask(String taskId) =>
      (select(photos)..where((t) => t.taskId.equals(taskId))).get();
```

- [ ] **Step 5: Apply and pull photo rows**

In `server/lib/src/sync/sync_service.dart`, add a case after `SyncChangeSubtask` — it is the subtask case with the row type changed, because a photo hangs off a task exactly as a subtask does:

```dart
      case SyncChangePhoto(:final row):
        final task = await _db.taskById(row.taskId);
        if (task == null) return 'unknown_task';
        if (!roles.containsKey(task.listId)) return 'forbidden';
        final skew = _checkHlc(row.updatedAt);
        if (skew != null) return skew;
        final existing = await _db.photoById(row.id);
        final oldTask = existing == null || existing.taskId == row.taskId
            ? null
            : await _db.taskById(existing.taskId);
        final oldListId = oldTask?.listId;
        final moved = oldListId != null && oldListId != task.listId;
        if (moved && !roles.containsKey(oldListId)) return 'forbidden';
        if (!incomingWins(existing, row)) {
          await _handBack(
            SyncEntity.photo,
            row.id,
            oldListId ?? task.listId,
            userId,
            incoming: row.updatedAt,
            held: existing!.updatedAt,
          );
          return null;
        }
        await _db.into(_db.photos).insertOnConflictUpdate(row.toInsertable());
        _accept(row.updatedAt);
        if (moved) {
          await _db.logRevoke(SyncEntity.photo, row.id, listId: oldListId);
          touched.add(oldListId);
        }
        await _db.logUpsert(SyncEntity.photo, row.id, task.listId);
        touched.add(task.listId);
        return null;
```

A task moving between lists already carries its subtasks; it must carry its photos the same way. In the `SyncChangeTask` case, beside the subtask handling:

```dart
        final subtasks = moved ? await _db.subtasksOfTask(row.id) : <Subtask>[];
        final taskPhotos = moved ? await _db.photosOfTask(row.id) : <Photo>[];
        if (moved) {
          await _db.logRevoke(SyncEntity.task, row.id, listId: oldListId);
          for (final sub in subtasks) {
            await _db.logRevoke(SyncEntity.subtask, sub.id, listId: oldListId);
          }
          for (final p in taskPhotos) {
            await _db.logRevoke(SyncEntity.photo, p.id, listId: oldListId);
          }
          touched.add(oldListId);
        }
        await _db.logUpsert(SyncEntity.task, row.id, row.listId);
        for (final sub in subtasks) {
          await _db.logUpsert(SyncEntity.subtask, sub.id, row.listId);
        }
        for (final p in taskPhotos) {
          await _db.logUpsert(SyncEntity.photo, p.id, row.listId);
        }
```

In `_pull`, fetch and wrap the new rows:

```dart
    final subtaskRows = await _subtasksById(idsFor(SyncEntity.subtask));
    final photoRows = await _photosById(idsFor(SyncEntity.photo));
```

```dart
        SyncEntity.subtask => _wrap(
          subtaskRows[entry.rowId],
          SyncChange.subtask,
        ),
        SyncEntity.photo => _wrap(photoRows[entry.rowId], SyncChange.photo),
```

and the query beside `_subtasksById`:

```dart
  Future<Map<String, Photo>> _photosById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.photos,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r};
  }
```

- [ ] **Step 6: Run the tests**

Run: `cd server && dart test test/sync_service_test.dart test/e2e_sync_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add server
git commit -m "feat(server): carry photo rows through sync

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 4: The blob store

**Files:**
- Create: `server/lib/src/blobs/blob_store.dart`
- Test: `server/test/blob_store_test.dart`
- Modify: `server/lib/nemo_server.dart`

**Interfaces:**
- Consumes: nothing but `dart:io`.
- Produces: `BlobStore(String root)` with `File fileFor(String sha256)`, `Future<bool> exists(String sha256)`, `Future<void> write(String sha256, List<int> bytes)`, `Stream<List<int>> read(String sha256)`, `Future<void> delete(String sha256)`, and `static String hashOf(List<int> bytes)`.

- [ ] **Step 1: Write the failing test**

Create `server/test/blob_store_test.dart`:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late BlobStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('nemo-blobs');
    store = BlobStore(root.path);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('writes bytes to a path fanned out by their hash', () async {
    final bytes = [1, 2, 3, 4];
    final hash = sha256.convert(bytes).toString();
    expect(BlobStore.hashOf(bytes), hash);
    expect(await store.exists(hash), isFalse);

    await store.write(hash, bytes);

    expect(await store.exists(hash), isTrue);
    expect(
      store.fileFor(hash).path,
      '${root.path}/${hash.substring(0, 2)}/${hash.substring(2, 4)}/$hash',
    );
    expect(await store.read(hash).expand((c) => c).toList(), bytes);
  });

  test('writing the same hash twice leaves one file', () async {
    final bytes = [9, 9, 9];
    final hash = BlobStore.hashOf(bytes);
    await store.write(hash, bytes);
    await store.write(hash, bytes);
    expect(
      root.listSync(recursive: true).whereType<File>().length,
      1,
    );
  });

  test('deleting removes the file and forgets it existed', () async {
    final bytes = [7];
    final hash = BlobStore.hashOf(bytes);
    await store.write(hash, bytes);
    await store.delete(hash);
    expect(await store.exists(hash), isFalse);
    // Deleting what is not there is not an error: a sweep may race a
    // delete that already happened.
    await store.delete(hash);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd server && dart test test/blob_store_test.dart`
Expected: FAIL — `Undefined name 'BlobStore'`.

- [ ] **Step 3: Write the store**

Create `server/lib/src/blobs/blob_store.dart`:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The bytes of every picture the server holds, on disk, named by content.
///
/// A hash is the whole identity: the same picture uploaded twice is one
/// file, and a file can never be the wrong bytes for its name. The two
/// levels of directory keep any one directory from growing to the size of
/// the whole store.
class BlobStore {
  BlobStore(this.root);

  final String root;

  static String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

  File fileFor(String sha256) => File(
    '$root/${sha256.substring(0, 2)}/${sha256.substring(2, 4)}/$sha256',
  );

  Future<bool> exists(String sha256) => fileFor(sha256).exists();

  Future<void> write(String sha256, List<int> bytes) async {
    final file = fileFor(sha256);
    await file.parent.create(recursive: true);
    // Written beside the target and renamed, so a request cut off halfway
    // never leaves a short file under a hash that promises the whole one.
    final temp = File('${file.path}.part');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  Stream<List<int>> read(String sha256) => fileFor(sha256).openRead();

  Future<void> delete(String sha256) async {
    final file = fileFor(sha256);
    if (await file.exists()) await file.delete();
  }
}
```

Export it from `server/lib/nemo_server.dart` beside the other exports:

```dart
export 'src/blobs/blob_store.dart';
```

- [ ] **Step 4: Run the test**

Run: `cd server && dart test test/blob_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server
git commit -m "feat(server): store blobs on disk, named by their hash

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 5: The blob endpoints

**Files:**
- Create: `server/lib/src/blobs/blob_service.dart`
- Modify: `server/lib/src/sync/sync_log_writer.dart`
- Modify: `server/lib/src/config.dart`
- Modify: `server/lib/src/http/handler.dart`
- Modify: `server/lib/nemo_server.dart`
- Modify: `server/test/support/test_server.dart`
- Test: `server/test/blob_endpoints_test.dart`
- Test: `server/test/config_test.dart`

**Interfaces:**
- Consumes: `BlobStore` (Task 4), `Photos`/`Blobs` tables (Task 2), `ApiException`, `requireAuth`, `request.user`.
- Produces: `Config.blobDir`, `Config.maxBlobBytes`, `Config.accountQuotaBytes`; `BlobService(db, store, {required int maxBlobBytes, required int accountQuotaBytes, DateTime Function()? now})` with `Future<void> put(String userId, String sha256, List<int> bytes)` and `Future<Stream<List<int>>> get(String userId, String sha256)`; `ServerDatabase.canSeeBlob(userId, sha256)` and `ServerDatabase.bytesOwnedBy(userId)`; routes `POST`/`GET /api/v1/blobs/<hash>`; `createHandler(..., BlobService? blobs)`.

- [ ] **Step 1: Write the failing test**

Create `server/test/blob_endpoints_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';
import 'support/test_server.dart';

void main() {
  late TestServer server;

  tearDown(() => server.close());

  /// Pushes a list, a task and a photo naming [hash], as [token]'s owner.
  Future<void> attach(String token, String hash) async {
    final clock = deviceClock('ben');
    final request = SyncRequest(
      changes: [
        SyncChange.list(list('l1', clock)),
        SyncChange.task(task('t1', 'l1', clock)),
        SyncChange.photo(photo('p1', 't1', clock, sha: hash)),
      ],
    );
    final response = await server.post(
      '/api/v1/sync',
      request.toJson(),
      token: token,
    );
    expect(response.statusCode, 200);
  }

  test('uploads bytes, refuses a mismatched hash, and serves them back',
      () async {
    server = await TestServer.start();
    final token = await server.signup('ben');
    final bytes = utf8.encode('a tiny picture');
    final hash = sha256.convert(bytes).toString();

    final wrong = await server.putBytes('/api/v1/blobs/${'b' * 64}', bytes,
        token: token);
    expect(wrong.statusCode, 400);
    expect(jsonDecode(wrong.body), {'error': 'hash_mismatch'});

    final first = await server.putBytes('/api/v1/blobs/$hash', bytes,
        token: token);
    expect(first.statusCode, 200);
    // A second upload of the same bytes stores nothing new.
    final again = await server.putBytes('/api/v1/blobs/$hash', bytes,
        token: token);
    expect(again.statusCode, 200);
    expect(await server.db.select(server.db.blobs).get(), hasLength(1));

    await attach(token, hash);
    final fetched = await server.get('/api/v1/blobs/$hash', token: token);
    expect(fetched.statusCode, 200);
    expect(fetched.bodyBytes, bytes);
  });

  test('bytes nobody has attached to a task you can see are not found',
      () async {
    server = await TestServer.start();
    final ben = await server.signup('ben');
    final mallory = await server.signup('mallory');
    final bytes = utf8.encode('private');
    final hash = sha256.convert(bytes).toString();
    await server.putBytes('/api/v1/blobs/$hash', bytes, token: ben);
    await attach(ben, hash);

    final denied = await server.get('/api/v1/blobs/$hash', token: mallory);
    expect(denied.statusCode, 404);
    expect(jsonDecode(denied.body), {'error': 'not_found'});
    expect(
      (await server.get('/api/v1/blobs/$hash')).statusCode,
      401,
    );
  });

  test('a blob over the cap is refused and a full account is told so',
      () async {
    server = await TestServer.start(maxBlobBytes: 8, accountQuotaBytes: 16);
    final token = await server.signup('ben');

    final big = List.filled(9, 1);
    final tooBig = await server.putBytes(
      '/api/v1/blobs/${sha256.convert(big)}',
      big,
      token: token,
    );
    expect(tooBig.statusCode, 413);
    expect(jsonDecode(tooBig.body), {'error': 'blob_too_large'});

    for (final fill in [2, 3]) {
      final bytes = List.filled(8, fill);
      final ok = await server.putBytes(
        '/api/v1/blobs/${sha256.convert(bytes)}',
        bytes,
        token: token,
      );
      expect(ok.statusCode, 200);
    }
    final over = List.filled(8, 4);
    final full = await server.putBytes(
      '/api/v1/blobs/${sha256.convert(over)}',
      over,
      token: token,
    );
    expect(full.statusCode, 507);
    expect(jsonDecode(full.body), {'error': 'quota_exceeded'});
  });
}
```

Add to `server/test/config_test.dart`, inside the existing environment test or as its own:

```dart
  test('blob settings come from the environment', () {
    final config = Config.fromEnv({
      'NEMO_BLOB_DIR': '/srv/blobs',
      'NEMO_MAX_BLOB_BYTES': '1024',
      'NEMO_ACCOUNT_QUOTA_BYTES': '4096',
    });
    expect(config.blobDir, '/srv/blobs');
    expect(config.maxBlobBytes, 1024);
    expect(config.accountQuotaBytes, 4096);

    const fallback = Config();
    expect(fallback.blobDir, '/data/blobs');
    expect(fallback.maxBlobBytes, 5 * 1024 * 1024);
    expect(fallback.accountQuotaBytes, 500 * 1024 * 1024);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && dart test test/blob_endpoints_test.dart test/config_test.dart`
Expected: FAIL — `putBytes` and the blob config fields do not exist.

- [ ] **Step 3: Extend the test server**

In `server/test/support/test_server.dart`, take the new settings and add a raw-bytes helper. The blob directory is a temporary one deleted on close:

```dart
  TestServer._(this.db, this.hub, this.auth, this._server, this._blobDir);

  final Directory _blobDir;

  static Future<TestServer> start({
    bool? allowSignup = true,
    String? webDir,
    List<String> corsOrigins = const [],
    DateTime Function()? now,
    RateLimiter? limiter,
    String version = 'dev',
    int maxBlobBytes = 5 * 1024 * 1024,
    int accountQuotaBytes = 500 * 1024 * 1024,
  }) async {
    final db = ServerDatabase.memory();
    final blobDir = Directory.systemTemp.createTempSync('nemo-test-blobs');
    final hub = EventHub(heartbeat: const Duration(milliseconds: 200));
    final auth = AuthService(
      db,
      allowSignup: allowSignup,
      now: now,
      bcryptRounds: 4,
    );
    final handler = createHandler(
      db: db,
      config: Config(
        webDir: webDir ?? '/nonexistent/web',
        allowSignup: allowSignup,
        corsOrigins: corsOrigins,
        version: version,
        blobDir: blobDir.path,
        maxBlobBytes: maxBlobBytes,
        accountQuotaBytes: accountQuotaBytes,
      ),
      auth: auth,
      hub: hub,
      now: now,
      limiter: limiter,
    );
    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    return TestServer._(db, hub, auth, server, blobDir);
  }

  Future<http.Response> putBytes(
    String path,
    List<int> bytes, {
    String? token,
  }) => http.post(
    uri(path),
    headers: {
      'content-type': 'image/jpeg',
      if (token != null) 'authorization': 'Bearer $token',
    },
    body: bytes,
  );
```

and in `close()`, after the database:

```dart
  Future<void> close() async {
    await _server.close(force: true);
    await hub.close();
    await db.close();
    if (_blobDir.existsSync()) _blobDir.deleteSync(recursive: true);
  }
```

- [ ] **Step 4: Add the config fields**

In `server/lib/src/config.dart`, add to the constructor, the factory and the fields:

```dart
    this.blobDir = '/data/blobs',
    this.maxBlobBytes = 5 * 1024 * 1024,
    this.accountQuotaBytes = 500 * 1024 * 1024,
```

```dart
      blobDir: read('NEMO_BLOB_DIR') ?? '/data/blobs',
      maxBlobBytes:
          int.tryParse(read('NEMO_MAX_BLOB_BYTES') ?? '') ?? 5 * 1024 * 1024,
      accountQuotaBytes:
          int.tryParse(read('NEMO_ACCOUNT_QUOTA_BYTES') ?? '') ??
          500 * 1024 * 1024,
```

```dart
  /// Where the bytes of pictures live. One file per distinct SHA-256.
  final String blobDir;

  /// The largest single upload accepted. Well above what the app produces:
  /// it is here to stop a client that is not the app.
  final int maxBlobBytes;

  /// How much one account may store in total before uploads are refused.
  final int accountQuotaBytes;
```

- [ ] **Step 5: Add the two queries**

In `server/lib/src/sync/sync_log_writer.dart`:

```dart
  /// Whether [userId] is a member of any list holding a live photo that
  /// names [sha256]. Losing a share loses the pictures with the tasks.
  Future<bool> canSeeBlob(String userId, String sha256) async {
    final row = await customSelect(
      'select 1 from photos p '
      'join tasks t on t.id = p.task_id '
      'join list_members m on m.list_id = t.list_id '
      'where p.sha256 = ? and p.deleted_at is null and m.user_id = ? '
      'limit 1',
      variables: [Variable<String>(sha256), Variable<String>(userId)],
      readsFrom: {photos, tasks, listMembers},
    ).getSingleOrNull();
    return row != null;
  }

  /// How many bytes of blobs [userId] is already being charged for.
  Future<int> bytesOwnedBy(String userId) async {
    final row = await customSelect(
      'select coalesce(sum(byte_size), 0) as total from blobs '
      'where owner_user_id = ?',
      variables: [Variable<String>(userId)],
      readsFrom: {blobs},
    ).getSingle();
    return row.read<int>('total');
  }
```

- [ ] **Step 6: Write the service**

Create `server/lib/src/blobs/blob_service.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/blobs/blob_store.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

/// Accepting and handing back the bytes of pictures.
///
/// A blob is immutable and named by its content, so there is no merge, no
/// conflict and no version: the only questions are whether the bytes are
/// what they claim to be, whether this account may store them, and whether
/// this account may read them.
class BlobService {
  BlobService(
    this._db,
    this._store, {
    required this.maxBlobBytes,
    required this.accountQuotaBytes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ServerDatabase _db;
  final BlobStore _store;
  final DateTime Function() _now;
  final int maxBlobBytes;
  final int accountQuotaBytes;

  Future<void> put(String userId, String sha256, List<int> bytes) async {
    if (bytes.length > maxBlobBytes) {
      throw const ApiException(413, 'blob_too_large');
    }
    if (BlobStore.hashOf(bytes) != sha256.toLowerCase()) {
      throw const ApiException(400, 'hash_mismatch');
    }
    // Already held: the upload is a no-op, and it costs the caller nothing
    // whether they were the one who paid for it or not.
    final existing = await (_db.select(
      _db.blobs,
    )..where((t) => t.sha256.equals(sha256))).getSingleOrNull();
    if (existing != null) {
      if (!await _store.exists(sha256)) await _store.write(sha256, bytes);
      return;
    }
    final held = await _db.bytesOwnedBy(userId);
    if (held + bytes.length > accountQuotaBytes) {
      throw const ApiException(507, 'quota_exceeded');
    }
    // The file first: a row naming bytes that are not there would be a
    // download that 404s, while a file no row names is swept later.
    await _store.write(sha256, bytes);
    await _db
        .into(_db.blobs)
        .insert(
          BlobsCompanion.insert(
            sha256: sha256,
            byteSize: bytes.length,
            ownerUserId: userId,
            createdAt: _now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// The bytes, or a 404 — which is also the answer for bytes that exist
  /// but are attached to nothing this account can see. Saying "forbidden"
  /// would confirm the picture exists.
  Future<Stream<List<int>>> get(String userId, String sha256) async {
    if (!await _db.canSeeBlob(userId, sha256)) {
      throw const ApiException(404, 'not_found');
    }
    if (!await _store.exists(sha256)) {
      throw const ApiException(404, 'not_found');
    }
    return _store.read(sha256);
  }
}
```

Export it beside `BlobStore` in `server/lib/nemo_server.dart`:

```dart
export 'src/blobs/blob_service.dart';
```

- [ ] **Step 7: Mount the routes**

In `server/lib/src/http/handler.dart`, add the import, the parameter, the service and the two routes.

```dart
import 'package:nemo_server/src/blobs/blob_service.dart';
import 'package:nemo_server/src/blobs/blob_store.dart';
```

```dart
Handler createHandler({
  required ServerDatabase db,
  required Config config,
  AuthService? auth,
  SyncService? sync,
  MembersService? members,
  BlobService? blobs,
  EventHub? hub,
  RateLimiter? limiter,
  DateTime Function()? now,
}) {
```

```dart
  final blobService =
      blobs ??
      BlobService(
        db,
        BlobStore(config.blobDir),
        maxBlobBytes: config.maxBlobBytes,
        accountQuotaBytes: config.accountQuotaBytes,
        now: now,
      );
```

Inside the `api` router, after the `/sync` route:

```dart
    ..post('/blobs/<hash>', (Request request, String hash) async {
      // Checked before a byte is read: an oversized upload should cost the
      // server the header, not the body.
      final declared = request.contentLength;
      if (declared != null && declared > config.maxBlobBytes) {
        throw const ApiException(413, 'blob_too_large');
      }
      final bytes = <int>[];
      await for (final chunk in request.read()) {
        bytes.addAll(chunk);
        if (bytes.length > config.maxBlobBytes) {
          throw const ApiException(413, 'blob_too_large');
        }
      }
      await blobService.put(request.user.id, hash, bytes);
      return jsonResponse({'ok': true});
    })
    ..get('/blobs/<hash>', (Request request, String hash) async {
      final bytes = await blobService.get(request.user.id, hash);
      return Response.ok(
        bytes,
        headers: {
          'content-type': 'image/jpeg',
          // Content-addressed: these bytes can never become other bytes.
          'cache-control': 'private, max-age=31536000, immutable',
        },
      );
    })
```

- [ ] **Step 8: Run the tests**

Run: `cd server && dart test`
Expected: PASS, whole suite.

- [ ] **Step 9: Commit**

```bash
git add server
git commit -m "feat(server): upload and serve the bytes of pictures

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 6: Purging photos and sweeping blobs

**Files:**
- Modify: `server/lib/src/maintenance/purge_service.dart`
- Test: `server/test/purge_service_test.dart`

**Interfaces:**
- Consumes: `Photos`, `Blobs`, `BlobStore`, `logRevoke`.
- Produces: `PurgeService(db, {BlobStore? blobs, DateTime Function()? now})`; `PurgeReport(..., int photos, int blobs)` with `total` counting photo rows (blob files are reported separately in `blobs`).

- [ ] **Step 1: Write the failing test**

Append to `server/test/purge_service_test.dart`. The file provides `db`,
`now` and a `purge()` helper; widen that helper so a test can hand it a
store:

```dart
  PurgeService purge({BlobStore? blobs}) =>
      PurgeService(db, blobs: blobs, now: () => now);
```

Then the test itself, with `import 'dart:io';` added at the top:

```dart
  test('a purged task takes its photos, and orphaned bytes are swept',
      () async {
    final root = Directory.systemTemp.createTempSync('nemo-purge-blobs');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = BlobStore(root.path);

    String stamp(Duration ago) => Hlc(
      millis: now.subtract(ago).millisecondsSinceEpoch,
      counter: 0,
      node: 'a',
    ).toString();
    final old = stamp(const Duration(days: 60));
    final live = stamp(Duration.zero);

    await db.into(db.lists).insert(
      TaskList(id: 'l1', name: 'L', sortKey: 'V', updatedAt: live)
          .toInsertable(),
    );
    await db.into(db.tasks).insert(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'T',
        sortKey: 'V',
        updatedAt: old,
        deletedAt: old,
      ).toInsertable(),
    );
    await db.into(db.photos).insert(
      Photo(
        id: 'p1',
        taskId: 't1',
        sha256: 'a' * 64,
        byteSize: 3,
        width: 1,
        height: 1,
        sortKey: 'V',
        updatedAt: old,
      ).toInsertable(),
    );

    Future<void> blob(String hash, Duration ago) async {
      await store.write(hash, [1, 2, 3]);
      await db.into(db.blobs).insert(
        BlobsCompanion.insert(
          sha256: hash,
          byteSize: 3,
          ownerUserId: 'u1',
          createdAt: now.subtract(ago).millisecondsSinceEpoch,
        ),
      );
    }

    await blob('a' * 64, const Duration(days: 60)); // held by p1, until p1 goes
    await blob('b' * 64, const Duration(days: 60)); // orphaned and old: swept
    await blob('c' * 64, const Duration(days: 1)); // an upload mid-flight

    final report = await purge(blobs: store).purge();

    expect(report.photos, 1);
    expect(report.blobs, 2);
    expect(await db.photoById('p1'), isNull);
    expect(await store.exists('a' * 64), isFalse);
    expect(await store.exists('b' * 64), isFalse);
    expect(
      await store.exists('c' * 64),
      isTrue,
      reason: 'bytes uploaded a moment ago are waiting for the row that '
          'will name them',
    );
    final logged = await (db.select(db.syncLog)
          ..where((t) => t.entity.equals('photo')))
        .get();
    expect(logged.single.op, 'revoke');
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd server && dart test test/purge_service_test.dart`
Expected: FAIL — `PurgeService` takes no `blobs`, `PurgeReport` has no `photos`.

- [ ] **Step 3: Extend the report and the service**

In `server/lib/src/maintenance/purge_service.dart`:

```dart
class PurgeReport {
  const PurgeReport({
    this.lists = 0,
    this.tasks = 0,
    this.subtasks = 0,
    this.photos = 0,
    this.blobs = 0,
  });

  final int lists;
  final int tasks;
  final int subtasks;
  final int photos;

  /// Blob files swept. Not part of [total]: they are bytes, not rows, and
  /// no client is waiting to be told about them.
  final int blobs;

  int get total => lists + tasks + subtasks + photos;

  @override
  String toString() =>
      '$lists list(s), $tasks task(s), $subtasks subtask(s), '
      '$photos photo(s), $blobs blob(s)';
}
```

```dart
  PurgeService(this._db, {BlobStore? blobs, DateTime Function()? now})
    : _blobs = blobs,
      _now = now ?? DateTime.now;

  final ServerDatabase _db;
  final BlobStore? _blobs;
```

Inside `purge`, alongside the existing child collection:

```dart
      final photos = await _oldPhotos(cutoff);
      final photoIds = {
        for (final p in photos) p.id,
        for (final row in await _childPhotos(taskIds)) row.id,
      };

      final report = PurgeReport(
        lists: lists.length,
        tasks: taskIds.length,
        subtasks: subtaskIds.length,
        photos: photoIds.length,
        blobs: dryRun ? (await _orphanBlobs(cutoff)).length : 0,
      );
      if (dryRun) return report;
```

Then, with the other children (photos are retired and deleted before their tasks, for the same reason subtasks are):

```dart
      for (final id in photoIds) {
        await _retire(SyncEntity.photo, id, await _listOfPhoto(id));
      }
```

```dart
      await (_db.delete(_db.photos)..where((t) => t.id.isIn(photoIds))).go();
```

and after the row deletions, sweep the bytes:

```dart
      final swept = await _sweepBlobs(cutoff);
      return PurgeReport(
        lists: lists.length,
        tasks: taskIds.length,
        subtasks: subtaskIds.length,
        photos: photoIds.length,
        blobs: swept,
      );
```

Delete the earlier `return report;` that followed the row deletions so the report returned is the one carrying the sweep. Keep the `if (dryRun || report.total == 0) return report;` guard, but change it to `if (dryRun) return report;` and let a purge with no rows still sweep: bytes are orphaned by uploads that were never claimed, not only by purged rows.

The new queries, beside the existing ones:

```dart
  Future<List<Photo>> _oldPhotos(String cutoff) =>
      (_db.select(_db.photos)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Photo>> _childPhotos(Iterable<String> taskIds) async {
    final ids = taskIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(
      _db.photos,
    )..where((t) => t.taskId.isIn(ids))).get();
  }

  Future<String> _listOfPhoto(String id) async {
    final row = await _db.photoById(id);
    if (row != null) {
      final task = await _db.taskById(row.taskId);
      if (task != null) return task.listId;
    }
    return await _loggedListId(SyncEntity.photo, id);
  }

  /// Blobs no live photo row names any more, old enough that they are not
  /// bytes waiting for the row that is about to claim them.
  Future<List<BlobRow>> _orphanBlobs(String cutoff) {
    final stale = Hlc.parse(cutoff).millis;
    return (_db.select(_db.blobs)..where(
          (t) =>
              t.createdAt.isSmallerThanValue(stale) &
              t.sha256.isNotInQuery(
                _db.selectOnly(_db.photos)..addColumns([_db.photos.sha256]),
              ),
        ))
        .get();
  }

  Future<int> _sweepBlobs(String cutoff) async {
    final store = _blobs;
    final orphans = await _orphanBlobs(cutoff);
    if (orphans.isEmpty) return 0;
    for (final blob in orphans) {
      if (store != null) await store.delete(blob.sha256);
    }
    await (_db.delete(
      _db.blobs,
    )..where((t) => t.sha256.isIn(orphans.map((b) => b.sha256)))).go();
    return orphans.length;
  }
```

Add the import for the store at the top of the file:

```dart
import 'package:nemo_server/src/blobs/blob_store.dart';
```

- [ ] **Step 4: Run the tests**

Run: `cd server && dart test`
Expected: PASS. If `bin/nemo_server.dart` constructs a `PurgeService`, pass it `BlobStore(config.blobDir)` there too, so a scheduled purge sweeps files rather than only rows.

- [ ] **Step 5: Commit**

```bash
git add server
git commit -m "feat(server): purge photo rows and sweep the bytes nothing names

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 7: App schema and the outbox

**Files:**
- Modify: `app/lib/core/db/sync_tables.dart`
- Modify: `app/lib/core/db/app_tables.dart`
- Modify: `app/lib/core/db/app_database.dart`
- Modify: `app/lib/core/db/sync_writes.dart`
- Test: `app/test/core/db/sync_writes_test.dart`

**Interfaces:**
- Consumes: `Photo`, `SyncChangePhoto`.
- Produces: local tables `photos` and `blobs` (data class `BlobRow`: `sha256`, `byteSize`, `state`); `AppDatabase.schemaVersion == 3`; on `SyncWrites`: `upsertPhoto(Photo)`, `photoById(String)`, `photosOfTask(String)`, `rememberBlob(String sha256, {required int byteSize, required String state})`, `markBlobSynced(String sha256)`, `pendingBlobs()`, `missingBlobHashes()`, `forgetUnusedBlob(String sha256)`; `outboxChanges()` holds back photo rows whose blob is still `pendingUpload`.

- [ ] **Step 1: Write the failing test**

Append to `app/test/core/db/sync_writes_test.dart`:

```dart
  test('a photo waits in the outbox until its bytes have been uploaded',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final clock = testClock('a');
    const hash = 'a' * 64;

    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'T',
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );
    await db.rememberBlob(hash, byteSize: 12, state: 'pendingUpload');
    await db.upsertPhoto(
      Photo(
        id: 'p1',
        taskId: 't1',
        sha256: hash,
        byteSize: 12,
        width: 4,
        height: 3,
        sortKey: 'V',
        updatedAt: clock.now().toString(),
      ),
    );

    expect(
      (await db.outboxChanges()).whereType<SyncChangePhoto>(),
      isEmpty,
      reason: 'the server would hold a row whose bytes it cannot serve',
    );
    expect((await db.pendingBlobs()).single.sha256, hash);

    await db.markBlobSynced(hash);
    expect(
      (await db.outboxChanges()).whereType<SyncChangePhoto>().single.row.id,
      'p1',
    );
  });

  test('a pulled photo is applied, and revoking its task takes it away',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final clock = testClock('server');
    await db.applyRemote(
      SyncChange.task(
        Task(
          id: 't1',
          listId: 'l1',
          title: 'T',
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      ),
    );
    await db.applyRemote(
      SyncChange.photo(
        Photo(
          id: 'p1',
          taskId: 't1',
          sha256: 'b' * 64,
          byteSize: 9,
          width: 2,
          height: 2,
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      ),
    );
    expect(await db.photoById('p1'), isNotNull);
    expect(await db.missingBlobHashes(), ['b' * 64]);

    await db.applyRemote(
      const SyncChange.revoke(target: SyncEntity.task, id: 't1'),
    );
    expect(await db.photoById('p1'), isNull);
    expect(await db.missingBlobHashes(), isEmpty);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/core/db/sync_writes_test.dart`
Expected: FAIL — `upsertPhoto`, `rememberBlob` and friends are undefined.

- [ ] **Step 3: Add the tables**

Append to `app/lib/core/db/sync_tables.dart` the same `Photos` table as Task 2 declared on the server (identical columns, index and row class):

```dart
@TableIndex(name: 'photos_task_id', columns: {#taskId})
@UseRowClass(Photo, generateInsertable: true)
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  TextColumn get sortKey => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Append to `app/lib/core/db/app_tables.dart`:

```dart
/// What this device holds the bytes for, and whether the server has them.
///
/// Never synced: it is a note about this device's storage, not about the
/// picture. The bytes themselves are a file on Android and memory on the
/// web -- see `PhotoStore`.
@DataClassName('BlobRow')
class Blobs extends Table {
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();

  /// `pendingUpload` until the server has the bytes, then `synced`.
  TextColumn get state => text()();

  @override
  Set<Column<Object>> get primaryKey => {sha256};
}
```

- [ ] **Step 4: Register the tables and the migration**

In `app/lib/core/db/app_database.dart`:

```dart
@DriftDatabase(tables: [Lists, Tasks, Subtasks, Photos, Outbox, ListMeta, Kv, Blobs])
```

```dart
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Version 2 carries how often a task comes back. Null on every row
      // that existed before, which is what "happens once" already meant.
      if (from < 2) await m.addColumn(tasks, tasks.repeat);
      // Version 3 carries pictures: the rows, and what this device holds
      // the bytes for.
      if (from < 3) {
        await m.createTable(photos);
        await m.create(photosTaskId);
        await m.createTable(blobs);
      }
    },
    beforeOpen: (details) async {
      await customStatement('pragma foreign_keys = on');
    },
  );
```

- [ ] **Step 5: Extend the writes**

In `app/lib/core/db/sync_writes.dart`:

```dart
  Future<void> upsertPhoto(Photo row) => _writeLocal(
    SyncEntity.photo,
    row,
    () => into(photos).insertOnConflictUpdate(row.toInsertable()),
  );
```

```dart
  Future<Photo?> photoById(String id) =>
      (select(photos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Photo>> photosOfTask(String taskId) =>
      (select(photos)..where((t) => t.taskId.equals(taskId))).get();

  /// Records that this device holds bytes for [sha256].
  Future<void> rememberBlob(
    String sha256, {
    required int byteSize,
    required String state,
  }) => into(blobs).insertOnConflictUpdate(
    BlobsCompanion.insert(sha256: sha256, byteSize: byteSize, state: state),
  );

  Future<void> markBlobSynced(String sha256) =>
      (update(blobs)..where((t) => t.sha256.equals(sha256))).write(
        const BlobsCompanion(state: Value('synced')),
      );

  Future<List<BlobRow>> pendingBlobs() =>
      (select(blobs)..where((t) => t.state.equals('pendingUpload'))).get();

  /// Hashes named by a live photo row that this device does not hold.
  Future<List<String>> missingBlobHashes() async {
    final rows = await customSelect(
      'select distinct p.sha256 as sha256 from photos p '
      'where p.deleted_at is null '
      'and p.sha256 not in (select sha256 from blobs)',
      readsFrom: {photos, blobs},
    ).get();
    return [for (final r in rows) r.read<String>('sha256')];
  }

  /// Forgets a blob once no live photo row names it. Returns whether it
  /// was forgotten, so the caller knows to delete the bytes as well.
  Future<bool> forgetUnusedBlob(String sha256) async {
    final still = await (select(
      photos,
    )..where((t) => t.sha256.equals(sha256) & t.deletedAt.isNull())).get();
    if (still.isNotEmpty) return false;
    await (delete(blobs)..where((t) => t.sha256.equals(sha256))).go();
    return true;
  }
```

In `applyRemote`, before the revoke case:

```dart
      case SyncChangePhoto(:final row):
        final local = await photoById(row.id);
        if (incomingWins(local, row)) {
          await into(photos).insertOnConflictUpdate(row.toInsertable());
          await dropOutbox(SyncEntity.photo, row.id);
        }
        return null;
```

In `_revoke`, photos follow their task, and a task's photos follow its list:

```dart
      case SyncEntity.list:
        final taskIds = (await (select(
          tasks,
        )..where((t) => t.listId.equals(id))).get()).map((t) => t.id).toList();
        if (taskIds.isNotEmpty) {
          final subtaskIds = (await (select(
            subtasks,
          )..where((t) => t.taskId.isIn(taskIds))).get()).map((s) => s.id);
          final photoIds = (await (select(
            photos,
          )..where((t) => t.taskId.isIn(taskIds))).get()).map((p) => p.id);
          await (delete(outbox)..where(
                (t) =>
                    (t.entity.equals(SyncEntity.task.name) &
                        t.rowId.isIn(taskIds)) |
                    (t.entity.equals(SyncEntity.subtask.name) &
                        t.rowId.isIn(subtaskIds)) |
                    (t.entity.equals(SyncEntity.photo.name) &
                        t.rowId.isIn(photoIds)),
              ))
              .go();
          await (delete(subtasks)..where((t) => t.taskId.isIn(taskIds))).go();
          await (delete(photos)..where((t) => t.taskId.isIn(taskIds))).go();
        }
```

```dart
      case SyncEntity.task:
        final subtaskIds = (await (select(
          subtasks,
        )..where((t) => t.taskId.equals(id))).get()).map((s) => s.id);
        final photoIds = (await (select(
          photos,
        )..where((t) => t.taskId.equals(id))).get()).map((p) => p.id);
        await (delete(outbox)..where(
              (t) =>
                  (t.entity.equals(SyncEntity.subtask.name) &
                      t.rowId.isIn(subtaskIds)) |
                  (t.entity.equals(SyncEntity.photo.name) &
                      t.rowId.isIn(photoIds)),
            ))
            .go();
        await (delete(subtasks)..where((t) => t.taskId.equals(id))).go();
        await (delete(photos)..where((t) => t.taskId.equals(id))).go();
        await (delete(tasks)..where((t) => t.id.equals(id))).go();
      case SyncEntity.subtask:
        await (delete(subtasks)..where((t) => t.id.equals(id))).go();
      case SyncEntity.photo:
        await (delete(photos)..where((t) => t.id.equals(id))).go();
```

In `outboxChanges`, add the photo arm — and hold a photo back while its bytes are still only here:

```dart
        SyncEntity.photo => await _pushablePhoto(entry.rowId),
```

with, at the end of the extension:

```dart
  /// A photo row is only offered to the server once the server has its
  /// bytes. Pushing it first would leave every other device holding a row
  /// it cannot fetch a picture for.
  Future<SyncChange?> _pushablePhoto(String rowId) async {
    final row = await photoById(rowId);
    if (row == null) return null;
    final blob = await (select(
      blobs,
    )..where((t) => t.sha256.equals(row.sha256))).getSingleOrNull();
    if (blob != null && blob.state != 'synced') return _held;
    return SyncChange.photo(row);
  }
```

`outboxChanges` deletes the queue entry when a change comes back null, which is right for a row that no longer exists but wrong for one merely waiting. Give it a sentinel to tell the two apart — declare it beside the extension:

```dart
/// Returned for a queued row that is not ready to be pushed yet. It is not
/// sent and its queue entry is kept.
final _held = SyncChange.revoke(target: SyncEntity.photo, id: '__held__');
```

and in the loop:

```dart
      if (identical(change, _held)) continue;
      if (change == null) {
```

In `enqueueAll`:

```dart
    await add(SyncEntity.photo, await select(photos).get());
```

In `ackOutbox`, add the arm:

```dart
        SyncChangePhoto(:final row) => row.updatedAt,
```

In `clearLocalData`, before subtasks:

```dart
    await delete(photos).go();
    await delete(blobs).go();
```

- [ ] **Step 6: Generate, dump the schema, and run the tests**

Run:

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/
flutter test test/core/db
```

Expected: PASS, and `app/drift_schemas/drift_schema_v3.json` exists.

- [ ] **Step 7: Commit**

```bash
git add app
git commit -m "feat(app): store photo rows and remember which bytes are here

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 8: The photo pipeline

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/photos/data/photo_pipeline.dart`
- Test: `app/test/features/photos/photo_pipeline_test.dart`

**Interfaces:**
- Consumes: `package:image`, `package:crypto`.
- Produces: `ProcessedPhoto({required Uint8List bytes, required String sha256, required int width, required int height})` and `ProcessedPhoto? processPhoto(Uint8List raw, {int maxEdge = 2048, int quality = 85})` — null when the bytes are not an image this build can decode.

- [ ] **Step 1: Add the dependencies**

In `app/pubspec.yaml`, under `dependencies`, in alphabetical order:

```yaml
  image: ^4.5.4
  image_picker: ^1.2.0
```

Run: `cd app && flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `app/test/features/photos/photo_pipeline_test.dart`:

```dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nemo/features/photos/data/photo_pipeline.dart';

void main() {
  Uint8List sourceJpeg({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    // A gradient rather than a flat fill: a flat image survives any resize
    // unchanged, so it would not prove the resize happened.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image));
  }

  test('a large photo is scaled down to the long edge and re-encoded', () {
    final processed = processPhoto(sourceJpeg(width: 4000, height: 3000))!;
    expect(processed.width, 2048);
    expect(processed.height, 1536);
    expect(processed.bytes.length, lessThan(1024 * 1024));
    expect(processed.sha256, sha256.convert(processed.bytes).toString());
  });

  test('a tall photo is scaled by its own long edge', () {
    final processed = processPhoto(sourceJpeg(width: 1000, height: 4000))!;
    expect(processed.height, 2048);
    expect(processed.width, 512);
  });

  test('a small photo keeps its size but is still re-encoded', () {
    final source = sourceJpeg(width: 100, height: 80);
    final processed = processPhoto(source)!;
    expect(processed.width, 100);
    expect(processed.height, 80);
    // Re-encoded in every case: that is what drops the EXIF block, which
    // is where the camera wrote where the picture was taken.
    expect(processed.sha256, sha256.convert(processed.bytes).toString());
  });

  test('the same bytes always give the same hash', () {
    final source = sourceJpeg(width: 300, height: 200);
    expect(processPhoto(source)!.sha256, processPhoto(source)!.sha256);
  });

  test('bytes that are not an image are refused', () {
    expect(processPhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd app && flutter test test/features/photos/photo_pipeline_test.dart`
Expected: FAIL — `photo_pipeline.dart` does not exist.

- [ ] **Step 4: Write the pipeline**

Create `app/lib/features/photos/data/photo_pipeline.dart`:

```dart
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// A picture ready to be stored and uploaded.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.bytes,
    required this.sha256,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String sha256;
  final int width;
  final int height;
}

/// Turns whatever the camera or the file picker gave us into the one shape
/// nemo stores: a JPEG no larger than [maxEdge] on its long side.
///
/// Everything is re-encoded, including a picture already small enough. The
/// encode is what drops the EXIF block, and a phone writes the location and
/// the camera's serial number into it -- neither of which should travel to
/// a server, let alone to everyone a list is shared with.
///
/// Returns null for bytes that are not an image this build can read.
ProcessedPhoto? processPhoto(
  Uint8List raw, {
  int maxEdge = 2048,
  int quality = 85,
}) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  // Orientation is an EXIF tag, and dropping EXIF without applying it
  // first would turn every portrait photo on its side.
  final upright = img.bakeOrientation(decoded);
  final longest = upright.width > upright.height
      ? upright.width
      : upright.height;
  final scaled = longest <= maxEdge
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height ? maxEdge : null,
          height: upright.height > upright.width ? maxEdge : null,
          interpolation: img.Interpolation.average,
        );
  final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
  return ProcessedPhoto(
    bytes: bytes,
    sha256: sha256.convert(bytes).toString(),
    width: scaled.width,
    height: scaled.height,
  );
}
```

- [ ] **Step 5: Run the test**

Run: `cd app && flutter test test/features/photos/photo_pipeline_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app
git commit -m "feat(app): one shape for every picture that comes in

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 9: Where the bytes live on the device

**Files:**
- Create: `app/lib/features/photos/data/photo_store.dart`
- Create: `app/lib/features/photos/data/photo_store_io.dart`
- Create: `app/lib/features/photos/data/photo_store_web.dart`
- Modify: `app/lib/core/providers.dart`
- Test: `app/test/features/photos/photo_store_test.dart`

**Interfaces:**
- Consumes: `path_provider` (already a dependency).
- Produces: `abstract interface class PhotoStore { Future<void> put(String sha256, Uint8List bytes); Future<Uint8List?> get(String sha256); Future<void> remove(String sha256); }`; `FilePhotoStore(String directory)`; `MemoryPhotoStore({int maxEntries = 40})`; `createPhotoStore()` for the platform; providers `photoStoreProvider` and `photoDownloadEagerProvider`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/photos/photo_store_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/photos/data/photo_store_io.dart';

void main() {
  test('a file store keeps bytes across instances', () async {
    final dir = Directory.systemTemp.createTempSync('nemo-photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = Uint8List.fromList([1, 2, 3]);

    await FilePhotoStore(dir.path).put('a' * 64, bytes);
    expect(await FilePhotoStore(dir.path).get('a' * 64), bytes);

    await FilePhotoStore(dir.path).remove('a' * 64);
    expect(await FilePhotoStore(dir.path).get('a' * 64), isNull);
    // Removing what is not there is not an error: two deletes can race.
    await FilePhotoStore(dir.path).remove('a' * 64);
  });

  test('a memory store forgets the least recently used', () async {
    final store = MemoryPhotoStore(maxEntries: 2);
    await store.put('a' * 64, Uint8List.fromList([1]));
    await store.put('b' * 64, Uint8List.fromList([2]));
    // Touching 'a' makes 'b' the oldest.
    await store.get('a' * 64);
    await store.put('c' * 64, Uint8List.fromList([3]));

    expect(await store.get('b' * 64), isNull);
    expect(await store.get('a' * 64), isNotNull);
    expect(await store.get('c' * 64), isNotNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/features/photos/photo_store_test.dart`
Expected: FAIL — the files do not exist.

- [ ] **Step 3: Write the interface and the two stores**

Create `app/lib/features/photos/data/photo_store.dart`:

```dart
import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store_io.dart'
    if (dart.library.js_interop) 'package:nemo/features/photos/data/photo_store_web.dart';

/// Where the bytes of a picture live on this device.
///
/// Two implementations, chosen at compile time the way the certificate
/// trust adapter is: files on Android, memory on the web -- where there is
/// nothing worth persisting to, and where the browser may not be the
/// user's own.
abstract interface class PhotoStore {
  Future<void> put(String sha256, Uint8List bytes);
  Future<Uint8List?> get(String sha256);
  Future<void> remove(String sha256);
}

/// The store this platform uses. On Android the directory is created on
/// first use under the app's support directory.
Future<PhotoStore> openPhotoStore() => createPhotoStore();
```

Create `app/lib/features/photos/data/photo_store_io.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:path_provider/path_provider.dart';

/// Pictures as files, named by content, under the app's support directory.
class FilePhotoStore implements PhotoStore {
  FilePhotoStore(this.directory);

  final String directory;

  File _file(String sha256) => File('$directory/$sha256.jpg');

  @override
  Future<void> put(String sha256, Uint8List bytes) async {
    final file = _file(sha256);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    final file = _file(sha256);
    return await file.exists() ? await file.readAsBytes() : null;
  }

  @override
  Future<void> remove(String sha256) async {
    final file = _file(sha256);
    if (await file.exists()) await file.delete();
  }
}

Future<PhotoStore> createPhotoStore() async {
  final support = await getApplicationSupportDirectory();
  return FilePhotoStore('${support.path}/photos');
}
```

Create `app/lib/features/photos/data/photo_store_web.dart`:

```dart
import 'dart:collection';
import 'dart:typed_data';

import 'package:nemo/features/photos/data/photo_store.dart';

/// Pictures in memory, most recently used kept.
///
/// The web app is served by the server it syncs with and is never offline
/// for long, so bytes are fetched when a picture is shown rather than kept
/// -- and a browser that may be shared is not somewhere to leave someone's
/// photographs behind.
class MemoryPhotoStore implements PhotoStore {
  MemoryPhotoStore({this.maxEntries = 40});

  final int maxEntries;
  final _entries = LinkedHashMap<String, Uint8List>();

  @override
  Future<void> put(String sha256, Uint8List bytes) async {
    _entries
      ..remove(sha256)
      ..[sha256] = bytes;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  @override
  Future<Uint8List?> get(String sha256) async {
    final bytes = _entries.remove(sha256);
    if (bytes != null) _entries[sha256] = bytes;
    return bytes;
  }

  @override
  Future<void> remove(String sha256) async => _entries.remove(sha256);
}

Future<PhotoStore> createPhotoStore() async => MemoryPhotoStore();
```

Note the web file also needs `MemoryPhotoStore` visible to the test above, which imports `photo_store_io.dart`; export it from there is wrong (it is web-only), so the test imports both files directly. Add to the test's imports:

```dart
import 'package:nemo/features/photos/data/photo_store_web.dart';
```

- [ ] **Step 4: Add the providers**

In `app/lib/core/providers.dart`, beside the other platform providers:

```dart
/// Whether this platform downloads pictures ahead of being asked.
///
/// Android does: the app is expected to work with the network off, and a
/// placeholder where a photo should be is exactly the offline failure the
/// app exists to avoid. The web app fetches when it shows.
final photoDownloadEagerProvider = Provider<bool>((_) => !kIsWeb);

/// Where this device keeps the bytes of pictures. Overridden in tests.
final photoStoreProvider = Provider<PhotoStore>(
  (_) => throw UnimplementedError('override photoStoreProvider in main'),
);
```

with the import:

```dart
import 'package:nemo/features/photos/data/photo_store.dart';
```

In `app/lib/main.dart`, where `appDatabaseProvider` and `bootstrapProvider` are overridden, open the store before the first frame and override it the same way:

```dart
  final photoStore = await openPhotoStore();
```

```dart
        photoStoreProvider.overrideWithValue(photoStore),
```

- [ ] **Step 5: Run the tests**

Run: `cd app && flutter test test/features/photos`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app
git commit -m "feat(app): keep picture bytes as files, or in memory on the web

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 10: The photos repository

**Files:**
- Create: `app/lib/features/photos/data/photos_repository.dart`
- Create: `app/lib/features/photos/ui/photos_providers.dart`
- Test: `app/test/features/photos/photos_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` + `SyncWrites` (Task 7), `processPhoto` (Task 8), `PhotoStore` (Task 9), `HlcClock`, `SortKey`.
- Produces: `PhotosRepository(AppDatabase db, HlcClock clock, String Function() newId, PhotoStore store)` with `Stream<List<Photo>> watchByTask(String taskId)`, `Stream<Map<String, int>> watchCounts()`, `Future<Photo?> add(String taskId, Uint8List raw)`, `Future<void> delete(String id)`, `Future<Uint8List?> bytes(String sha256)`; providers `photosRepositoryProvider`, `photosByTaskProvider(String taskId)`, `photoCountsProvider`, `photoBytesProvider(String sha256)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/photos/photos_repository_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

  test('adding a photo stores the bytes and queues the row', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(db, testClock('a'), sequentialIds('p'), store);
    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'T',
        sortKey: 'V',
        updatedAt: testClock('a').now().toString(),
      ),
    );

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

  test('two photos of the same task keep the order they were added',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      MemoryPhotoStore(),
    );
    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'T',
        sortKey: 'V',
        updatedAt: testClock('a').now().toString(),
      ),
    );

    final first = (await repo.add('t1', jpeg(width: 10, height: 10)))!;
    final second = (await repo.add('t1', jpeg(width: 20, height: 20)))!;

    expect(first.sortKey.compareTo(second.sortKey), lessThan(0));
    expect(await repo.watchCounts().first, {'t1': 2});
  });

  test('deleting tombstones the row and drops bytes nothing else names',
      () async {
    final db = testDatabase();
    addTearDown(db.close);
    final store = MemoryPhotoStore();
    final repo = PhotosRepository(db, testClock('a'), sequentialIds('p'), store);
    await db.upsertTask(
      Task(
        id: 't1',
        listId: 'l1',
        title: 'T',
        sortKey: 'V',
        updatedAt: testClock('a').now().toString(),
      ),
    );
    final photo = (await repo.add('t1', jpeg()))!;

    await repo.delete(photo.id);

    final stored = await db.photoById(photo.id);
    expect(stored!.isDeleted, isTrue);
    expect(await store.get(photo.sha256), isNull);
    expect(await repo.watchByTask('t1').first, isEmpty);
  });

  test('bytes that are not a picture are refused', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final repo = PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      MemoryPhotoStore(),
    );
    expect(await repo.add('t1', Uint8List.fromList([1, 2, 3])), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd app && flutter test test/features/photos/photos_repository_test.dart`
Expected: FAIL — `photos_repository.dart` does not exist.

- [ ] **Step 3: Write the repository**

Create `app/lib/features/photos/data/photos_repository.dart`:

```dart
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// The pictures on a task: adding one, removing one, and finding its bytes.
class PhotosRepository {
  PhotosRepository(this._db, this._clock, this._newId, this._store);

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;
  final PhotoStore _store;

  Stream<List<Photo>> watchByTask(String taskId) =>
      (_db.select(_db.photos)
            ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
          .watch();

  /// How many pictures each task has, for the list tiles.
  Stream<Map<String, int>> watchCounts() =>
      (_db.select(_db.photos)..where((t) => t.deletedAt.isNull()))
          .watch()
          .map((rows) {
            final counts = <String, int>{};
            for (final row in rows) {
              counts[row.taskId] = (counts[row.taskId] ?? 0) + 1;
            }
            return counts;
          });

  Future<Uint8List?> bytes(String sha256) => _store.get(sha256);

  /// Hashes whose bytes the server does not have yet, so a picture can
  /// say so rather than looking like every other one.
  Stream<Set<String>> watchPendingHashes() =>
      (_db.select(_db.blobs)..where((t) => t.state.equals('pendingUpload')))
          .watch()
          .map((rows) => {for (final row in rows) row.sha256});

  /// Processes [raw], stores the bytes and queues the row. Returns null
  /// for bytes that are not a picture.
  Future<Photo?> add(String taskId, Uint8List raw) async {
    final processed = processPhoto(raw);
    if (processed == null) return null;
    final last =
        await (_db.select(_db.photos)
              ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    final photo = Photo(
      id: _newId(),
      taskId: taskId,
      sha256: processed.sha256,
      byteSize: processed.bytes.length,
      width: processed.width,
      height: processed.height,
      sortKey: last == null ? SortKey.first() : SortKey.after(last.sortKey),
      updatedAt: _clock.now().toString(),
    );
    await _store.put(processed.sha256, processed.bytes);
    // The blob is recorded before the row, so the row can never be found
    // pushable before the bytes it needs are known about.
    await _db.rememberBlob(
      processed.sha256,
      byteSize: processed.bytes.length,
      state: 'pendingUpload',
    );
    await _db.upsertPhoto(photo);
    return photo;
  }

  Future<void> delete(String id) async {
    final photo = await _db.photoById(id);
    if (photo == null) return;
    final stamp = _clock.now().toString();
    await _db.upsertPhoto(photo.copyWith(updatedAt: stamp, deletedAt: stamp));
    // The same picture may hang off another task -- the hash is the bytes,
    // not the attachment -- so the bytes only go when nothing names them.
    if (await _db.forgetUnusedBlob(photo.sha256)) {
      await _store.remove(photo.sha256);
    }
  }
}
```

- [ ] **Step 4: Wire the providers**

Create `app/lib/features/photos/ui/photos_providers.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photos_providers.g.dart';

final photosRepositoryProvider = Provider<PhotosRepository>(
  (ref) => PhotosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(photoStoreProvider),
  ),
);

@riverpod
Stream<List<Photo>> photosByTask(Ref ref, String taskId) =>
    ref.watch(photosRepositoryProvider).watchByTask(taskId);

@riverpod
Stream<Map<String, int>> photoCounts(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchCounts();

/// The bytes of one picture, or null while this device does not hold them.
@riverpod
Future<Uint8List?> photoBytes(Ref ref, String sha256) =>
    ref.watch(photosRepositoryProvider).bytes(sha256);

/// Pictures this device holds that the server has not taken yet.
@riverpod
Stream<Set<String>> pendingPhotoHashes(Ref ref) =>
    ref.watch(photosRepositoryProvider).watchPendingHashes();
```

- [ ] **Step 5: Generate and run the tests**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs && flutter test test/features/photos`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app
git commit -m "feat(app): add, order and remove the pictures on a task

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 11: Uploading and downloading bytes

**Files:**
- Modify: `app/lib/features/sync/data/sync_client.dart`
- Modify: `app/lib/features/sync/ui/sync_engine.dart`
- Modify: `app/test/support/fake_sync.dart`
- Test: `app/test/features/sync/sync_engine_test.dart`
- Test: `app/test/features/sync/sync_client_test.dart`

**Interfaces:**
- Consumes: `SyncClient`, `pendingBlobs`, `markBlobSynced`, `missingBlobHashes`, `rememberBlob`, `PhotoStore`, `photoDownloadEagerProvider`.
- Produces: `SyncClient.uploadBlob(String sha256, Uint8List bytes)`, `SyncClient.downloadBlob(String sha256)`; the engine uploads before pushing and downloads after pulling.

- [ ] **Step 1: Write the failing client test**

Append to `app/test/features/sync/sync_client_test.dart`. The file drives
dio through a `_FakeAdapter(respond)` and a `_dio(adapter)` helper, and
inspects `adapter.requests`:

```dart
  test('uploads bytes under their hash and fetches them back', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final adapter = _FakeAdapter(
      (options) => options.method == 'GET'
          ? ResponseBody.fromBytes(bytes, 200, headers: {
              Headers.contentTypeHeader: ['image/jpeg'],
            })
          : ResponseBody.fromString('{"ok":true}', 200, headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            }),
    );
    final client = SyncClient(
      _dio(adapter),
      baseUrl: 'https://nemo.test',
      token: 'secret',
    );

    await client.uploadBlob('a' * 64, bytes);
    expect(await client.downloadBlob('a' * 64), bytes);

    expect(
      adapter.requests.map((r) => '${r.method} ${r.uri.path}'),
      ['POST /api/v1/blobs/${'a' * 64}', 'GET /api/v1/blobs/${'a' * 64}'],
    );
    expect(
      adapter.requests.first.headers['authorization'],
      'Bearer secret',
    );
  });
```

Add `import 'dart:typed_data';` to the test's imports.

- [ ] **Step 2: Write the failing engine test**

The engine tests run on a `ProviderContainer` from the file's own
`container()` helper, not on `pumpApp`. Widen it to take extra overrides:

```dart
  Future<ProviderContainer> container({
    bool connected = true,
    RetryPolicy? retry,
    List<Override> extra = const [],
  }) async {
```

and add `...extra,` as the last entry of its `overrides` list. The helper
must also override the photo store for every test in the file, since the
engine now reads it:

```dart
        photoStoreProvider.overrideWithValue(store),
```

with `late MemoryPhotoStore store;` beside `late AppDatabase db;` and
`store = MemoryPhotoStore();` in the existing `setUp`.

Then the tests, appended to the same file:

```dart
  test('bytes are uploaded before the row that names them is pushed',
      () async {
    final c = await container();
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    final photo = (await PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    ).add('t1', smallJpeg()))!;

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.uploaded, [photo.sha256]);
    final pushed = client.pushes.expand((c) => c).whereType<SyncChangePhoto>();
    expect(pushed.single.row.id, photo.id);
    expect(
      client.uploadedBefore(photo.sha256),
      isTrue,
      reason: 'a row the server cannot serve bytes for is a broken picture '
          'on every other device',
    );
    expect(await db.pendingBlobs(), isEmpty);
  });

  test('a photo row that cannot be uploaded yet is held back', () async {
    final c = await container();
    client.failWith = const ApiError(507, 'quota_exceeded');
    await db.upsertTask(task('t1', testClock('a').now().toString()));
    await PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    ).add('t1', smallJpeg());

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(
      client.pushes.expand((c) => c).whereType<SyncChangePhoto>(),
      isEmpty,
    );
    expect(await db.pendingBlobs(), hasLength(1));
  });

  test('a pulled photo has its bytes fetched where downloads are eager',
      () async {
    const hash = 'c' * 64;
    final stamp = Hlc(millis: testNowMs, counter: 0, node: 'srv').toString();
    client.responses.add(
      SyncResponse(
        cursor: 1,
        serverHlc: stamp,
        changes: [
          SyncChange.task(task('t1', stamp)),
          SyncChange.photo(
            Photo(
              id: 'p1',
              taskId: 't1',
              sha256: hash,
              byteSize: 3,
              width: 1,
              height: 1,
              sortKey: 'V',
              updatedAt: stamp,
            ),
          ),
        ],
      ),
    );
    client.blobs[hash] = Uint8List.fromList([4, 5, 6]);
    final c = await container(
      extra: [photoDownloadEagerProvider.overrideWithValue(true)],
    );

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(await store.get(hash), [4, 5, 6]);
    expect(await db.missingBlobHashes(), isEmpty);
  });

  test('where downloads are not eager, nothing is fetched until it is shown',
      () async {
    const hash = 'd' * 64;
    final stamp = Hlc(millis: testNowMs, counter: 0, node: 'srv').toString();
    client.responses.add(
      SyncResponse(
        cursor: 1,
        serverHlc: stamp,
        changes: [
          SyncChange.task(task('t1', stamp)),
          SyncChange.photo(
            Photo(
              id: 'p1',
              taskId: 't1',
              sha256: hash,
              byteSize: 3,
              width: 1,
              height: 1,
              sortKey: 'V',
              updatedAt: stamp,
            ),
          ),
        ],
      ),
    );
    client.blobs[hash] = Uint8List.fromList([7]);
    final c = await container(
      extra: [photoDownloadEagerProvider.overrideWithValue(false)],
    );

    await c.read(syncEngineProvider.notifier).syncNow();

    expect(client.downloaded, isEmpty);
    expect(await db.missingBlobHashes(), [hash]);
  });
```

`smallJpeg()` is shared with Task 10's tests: put it in
`app/test/support/photos.dart` and import it from both files.

```dart
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A tiny real JPEG, so the pipeline has something it can decode.
Uint8List smallJpeg({int width = 20, int height = 16}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd app && flutter test test/features/sync`
Expected: FAIL — `uploadBlob` undefined, `FakeSyncClient` has no `blobs`.

- [ ] **Step 4: Extend the fake**

In `app/test/support/fake_sync.dart`:

```dart
  /// Bytes the fake server is holding, by hash.
  final Map<String, Uint8List> blobs = {};
  final List<String> uploaded = [];
  final List<String> downloaded = [];

  /// Hashes pushed as photo rows, in order, so a test can check that the
  /// bytes went first.
  final List<String> pushedPhotoHashes = [];

  bool uploadedBefore(String sha256) =>
      uploaded.contains(sha256) &&
      (!pushedPhotoHashes.contains(sha256) ||
          uploaded.indexOf(sha256) <= pushedPhotoHashes.indexOf(sha256));

  @override
  Future<void> uploadBlob(String sha256, Uint8List bytes) async {
    final failure = failWith;
    if (failure != null) throw failure;
    uploaded.add(sha256);
    blobs[sha256] = bytes;
  }

  @override
  Future<Uint8List> downloadBlob(String sha256) async {
    final failure = failWith;
    if (failure != null) throw failure;
    downloaded.add(sha256);
    final bytes = blobs[sha256];
    if (bytes == null) throw const ApiError(404, 'not_found');
    return bytes;
  }
```

and in `sync`, record the hashes as they are pushed:

```dart
    pushes.add(request.changes);
    for (final change in request.changes) {
      if (change is SyncChangePhoto) pushedPhotoHashes.add(change.row.sha256);
    }
```

- [ ] **Step 5: Add the client methods**

In `app/lib/features/sync/data/sync_client.dart`:

```dart
  /// Uploads the bytes of a picture. Idempotent: the server answers the
  /// same whether it already held them or not.
  Future<void> uploadBlob(String sha256, Uint8List bytes) => _send(
    () => _dio.postUri<Map<String, dynamic>>(
      uri('/blobs/$sha256'),
      data: Stream.value(bytes),
      options: Options(
        headers: {
          'authorization': 'Bearer $token',
          'content-length': bytes.length,
        },
        contentType: 'image/jpeg',
      ),
    ),
  );

  Future<Uint8List> downloadBlob(String sha256) async {
    final bytes = await _send<List<int>>(
      () => _dio.getUri<List<int>>(
        uri('/blobs/$sha256'),
        options: Options(
          headers: {'authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      ),
    );
    return Uint8List.fromList(bytes);
  }
```

Add the import:

```dart
import 'dart:typed_data';
```

- [ ] **Step 6: Add the engine phases**

In `app/lib/features/sync/ui/sync_engine.dart`, inside `_runOnce`, before the `while (hasMore)` loop:

```dart
    await _uploadPending(client);
```

and after the loop, before the duplicate-inbox merge:

```dart
    if (ref.read(photoDownloadEagerProvider)) await _downloadMissing(client);
```

with the two methods on the notifier:

```dart
  /// How many blobs move at once. Two: enough to keep a home connection
  /// busy, few enough that a sync is not one long upload.
  static const _blobConcurrency = 2;

  /// Sends the bytes of every picture the server does not have yet.
  ///
  /// A blob that lands flips to `synced`, which is what releases its row
  /// into the next push: the server never holds a photo row it cannot
  /// serve the picture for. A failure is left queued and tried again.
  Future<void> _uploadPending(SyncClient client) async {
    final db = ref.read(appDatabaseProvider);
    final store = ref.read(photoStoreProvider);
    final pending = await db.pendingBlobs();
    await _forEachLimited(pending.map((b) => b.sha256), (sha256) async {
      final bytes = await store.get(sha256);
      // Bytes gone from under us -- a cleared web tab -- leave a row that
      // can never be pushed. Forgetting the blob lets the photo row go
      // with the next revoke or be replaced by another device's copy.
      if (bytes == null) return;
      await client.uploadBlob(sha256, bytes);
      await db.markBlobSynced(sha256);
    });
  }

  /// Fetches the bytes of pictures that arrived as rows.
  Future<void> _downloadMissing(SyncClient client) async {
    final db = ref.read(appDatabaseProvider);
    final store = ref.read(photoStoreProvider);
    final missing = await db.missingBlobHashes();
    await _forEachLimited(missing, (sha256) async {
      final bytes = await client.downloadBlob(sha256);
      await store.put(sha256, bytes);
      await db.rememberBlob(
        sha256,
        byteSize: bytes.length,
        state: 'synced',
      );
    });
  }

  /// Runs [action] over [items], [_blobConcurrency] at a time. One item
  /// failing does not stop the rest: pictures are independent, and the
  /// next sync tries whatever is still missing.
  Future<void> _forEachLimited(
    Iterable<String> items,
    Future<void> Function(String) action,
  ) async {
    final queue = items.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        try {
          await action(item);
        } on ApiError catch (e) {
          // Left for the next round; a whole sync should not fail because
          // one picture did. But a refusal that will not change on its own
          // -- too large, or no room on the server -- is remembered and
          // said out loud beside the pictures, or the photo sits there
          // marked "not uploaded" for ever with no reason given.
          if (e.status == 413 || e.status == 507) {
            state = state.copyWith(photoError: e.code);
          }
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < _blobConcurrency; i++) worker(),
    ]);
  }
```

`photoError` is a new field on `SyncState`, beside `error`. In
`app/lib/features/sync/ui/sync_state.dart` add it to the constructor, the
field list and `copyWith` (with a `clearPhotoError` flag, following how
`clearError` is already done there):

```dart
  /// Why the server would not take a picture: `blob_too_large` or
  /// `quota_exceeded`. Separate from [error] because the sync itself
  /// succeeded -- only the picture did not.
  final String? photoError;
```

A successful upload clears it, at the top of `_uploadPending`:

```dart
    state = state.copyWith(clearPhotoError: true);
```

Add the imports the engine now needs:

```dart
import 'package:nemo/features/photos/data/photo_store.dart';
```

- [ ] **Step 7: Run the tests**

Run: `cd app && flutter test test/features/sync test/features/photos`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app
git commit -m "feat(app): move picture bytes around the sync, not through it

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 12: The screens

**Files:**
- Create: `app/lib/features/photos/ui/photo_thumbnail.dart`
- Create: `app/lib/features/photos/ui/photo_strip.dart`
- Create: `app/lib/features/photos/ui/photo_viewer.dart`
- Modify: `app/lib/features/tasks/ui/task_detail_screen.dart`
- Modify: `app/lib/core/widgets/task_tile.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`
- Test: `app/test/features/photos/photo_strip_test.dart`

**Interfaces:**
- Consumes: `photosByTaskProvider`, `photoCountsProvider`, `photoBytesProvider`, `photosRepositoryProvider`, `image_picker`.
- Produces: `PhotoThumbnail({required String sha256, required double size})`, `PhotoStrip({required String taskId})`, `showPhotoViewer(BuildContext, WidgetRef, {required String taskId, required int index})`; l10n keys `tasksPhotos`, `photosTakePhoto`, `photosChoose`, `photosNotAnImage`, `photosTooLarge`, `photosServerFull`.

- [ ] **Step 1: Add the strings**

`app/lib/l10n/app_en.arb`, after `tasksSubtaskHint`:

```json
  "tasksPhotos": "Photos",
  "photosTakePhoto": "Take photo",
  "photosChoose": "Choose from gallery",
  "photosAdd": "Add photo",
  "photosNotAnImage": "That file is not a picture.",
  "photosTooLarge": "That picture is too large for this server.",
  "photosServerFull": "The server has no room for more pictures.",
```

`app_de.arb`:

```json
  "tasksPhotos": "Fotos",
  "photosTakePhoto": "Foto aufnehmen",
  "photosChoose": "Aus Galerie wählen",
  "photosAdd": "Foto hinzufügen",
  "photosNotAnImage": "Diese Datei ist kein Bild.",
  "photosTooLarge": "Dieses Bild ist zu groß für diesen Server.",
  "photosServerFull": "Der Server hat keinen Platz mehr für Bilder.",
```

`app_it.arb`:

```json
  "tasksPhotos": "Foto",
  "photosTakePhoto": "Scatta foto",
  "photosChoose": "Scegli dalla galleria",
  "photosAdd": "Aggiungi foto",
  "photosNotAnImage": "Questo file non è un'immagine.",
  "photosTooLarge": "Questa immagine è troppo grande per questo server.",
  "photosServerFull": "Il server non ha più spazio per le immagini.",
```

Run: `cd app && flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Widget tests reach the photo store through `pumpApp`, so give it one. In
`app/test/support/pump_app.dart`, add a parameter and its override:

```dart
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String initialLocation = Routes.today,
  List<Object> overrides = const [],
  Size size = const Size(400, 800),
  Future<void> Function(AppDatabase db, TaskList inbox)? seed,
  bool settle = true,
  PhotoStore? photoStore,
}) async {
```

```dart
      photoStoreProvider.overrideWithValue(photoStore ?? MemoryPhotoStore()),
```

placed before `...overrides.cast()` so a test can still override it, with
the imports for `PhotoStore` and `MemoryPhotoStore`.

Then create `app/test/features/photos/photo_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  late MemoryPhotoStore store;

  setUp(() => store = MemoryPhotoStore());

  Future<void> seed(AppDatabase db, TaskList inbox) async {
    await db.upsertTask(
      Task(
        id: 't1',
        listId: inbox.id,
        title: 'Broken tap',
        sortKey: 'V',
        updatedAt: testClock('a').now().toString(),
      ),
    );
    await PhotosRepository(
      db,
      testClock('a'),
      sequentialIds('p'),
      store,
    ).add('t1', smallJpeg());
  }

  appTest('the strip shows a task photo and deletes it from the viewer', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      photoStore: store,
      seed: seed,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-photos')),
      200,
      // The subtask list is a scrollable of its own, so the one to drive
      // has to be named rather than guessed at.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-p1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-viewer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo-viewer-delete')));
    await tester.pumpAndSettle();
    expect((await app.db.photoById('p1'))!.isDeleted, isTrue);
    expect(find.byKey(const Key('photo-p1')), findsNothing);
  });

  appTest('a task with photos shows one on its tile', (tester) async {
    final app = await pumpApp(
      tester,
      photoStore: store,
      seed: seed,
    );
    // Today shows only what is due today; the task lives in the inbox.
    app.router.go(Routes.list(app.inbox.id));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tile-photo-t1')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd app && flutter test test/features/photos/photo_strip_test.dart`
Expected: FAIL — no widget with key `task-photos`.

- [ ] **Step 4: Write the thumbnail**

Create `app/lib/features/photos/ui/photo_thumbnail.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';

/// One picture at a fixed size, or a placeholder while this device does
/// not hold its bytes.
///
/// A placeholder rather than a spinner: a photo taken on another device
/// and not fetched yet is a normal state, not a thing in progress, and a
/// list of spinners reads as a broken screen.
class PhotoThumbnail extends ConsumerWidget {
  const PhotoThumbnail({
    required this.sha256,
    required this.size,
    this.radius = 10,
    super.key,
  });

  final String sha256;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = ref.watch(photoBytesProvider(sha256)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes == null)
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  size: size / 2.5,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            if (pending)
              Positioned(
                left: 2,
                bottom: 2,
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: size / 4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

`pending` is read beside the bytes, in the same `build`:

```dart
    final pending =
        ref.watch(pendingPhotoHashesProvider).value?.contains(sha256) ?? false;
```

- [ ] **Step 5: Write the strip and the viewer**

Create `app/lib/features/photos/ui/photo_strip.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photo_viewer.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The pictures on a task, with a button to add another.
class PhotoStrip extends ConsumerWidget {
  const PhotoStrip({required this.taskId, super.key});

  final String taskId;

  static const _size = 72.0;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final l = L.of(context);
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final photo = await ref
        .read(photosRepositoryProvider)
        .add(taskId, bytes);
    if (photo == null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.photosNotAnImage)));
    }
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.photosTakePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              key: const Key('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.photosChoose),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) await _add(context, ref, source);
  }

  /// What the server said when it would not take a picture.
  String? _refusal(L l, String? code) => switch (code) {
    'blob_too_large' => l.photosTooLarge,
    'quota_exceeded' => l.photosServerFull,
    _ => null,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final photos = ref.watch(photosByTaskProvider(taskId)).value ?? const [];
    final refusal = _refusal(
      l,
      ref.watch(syncEngineProvider.select((s) => s.photoError)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (refusal != null)
          Padding(
            key: const Key('photo-refusal'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              refusal,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        SizedBox(
      key: const Key('task-photos'),
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                key: Key('photo-${photos[i].id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () =>
                    showPhotoViewer(context, taskId: taskId, index: i),
                child: PhotoThumbnail(sha256: photos[i].sha256, size: _size),
              ),
            ),
          SizedBox.square(
            dimension: _size,
            child: OutlinedButton(
              key: const Key('photo-add'),
              onPressed: () => unawaited(_pick(context, ref)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Tooltip(
                message: l.photosAdd,
                child: const Icon(Icons.add_a_photo_outlined),
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }
}
```

Reindent the `ListView` and its children under the new `Column` — the
snippet above shows the shape, not the final whitespace; `dart format`
settles it.

Add the import for the engine provider:

```dart
import 'package:nemo/features/sync/ui/sync_engine.dart';
```

Create `app/lib/features/photos/ui/photo_viewer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Opens the task's pictures full screen, starting at [index].
Future<void> showPhotoViewer(
  BuildContext context, {
  required String taskId,
  required int index,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _PhotoViewer(taskId: taskId, initialIndex: index),
    fullscreenDialog: true,
  ),
);

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.taskId, required this.initialIndex});

  final String taskId;
  final int initialIndex;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late var _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final photos =
        ref.watch(photosByTaskProvider(widget.taskId)).value ?? const [];
    // The last picture deleted leaves nothing to look at.
    if (photos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    final current = _index.clamp(0, photos.isEmpty ? 0 : photos.length - 1);
    return Scaffold(
      key: const Key('photo-viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${current + 1} / ${photos.length}'),
        actions: [
          IconButton(
            key: const Key('photo-viewer-delete'),
            tooltip: l.commonDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: photos.isEmpty
                ? null
                : () => ref
                      .read(photosRepositoryProvider)
                      .delete(photos[current].id),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: PhotoThumbnail(
              sha256: photos[i].sha256,
              size: MediaQuery.sizeOf(context).width,
              radius: 0,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Put the strip on the detail screen**

In `app/lib/features/tasks/ui/task_detail_screen.dart`, add the import:

```dart
import 'package:nemo/features/photos/ui/photo_strip.dart';
```

and, in the `ListView`, directly after the notes `TextField` and before
the `_Label(l.tasksDue)` section — a picture belongs with what the task
says, not at the bottom under the settings:

```dart
            const SizedBox(height: 20),
            _Label(l.tasksPhotos),
            PhotoStrip(taskId: task.id),
```

`image_picker` needs no manifest changes on Android: it launches the
system camera and the photo picker by intent rather than reading storage
itself. On the web it is served by `image_picker_for_web`, which comes
with the package; `ImageSource.camera` there is a file input with the
`capture` attribute, which a phone browser opens as the camera and a
desktop browser as a file chooser.

- [ ] **Step 7: Put a thumbnail on the tile**

In `app/lib/core/widgets/task_tile.dart`, add the imports:

```dart
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
```

and, inside `build`, beside the other watches:

```dart
    final photos = ref.watch(photoCountsProvider).value?[task.id] ?? 0;
    final firstPhoto = photos == 0
        ? null
        : ref.watch(photosByTaskProvider(task.id)).value?.firstOrNull;
```

then, in the `Row`, before the priority flag:

```dart
            if (firstPhoto != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 4),
                child: Stack(
                  key: Key('tile-photo-${task.id}'),
                  children: [
                    PhotoThumbnail(sha256: firstPhoto.sha256, size: 40),
                    if (photos > 1)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.85),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            child: Text(
                              '+${photos - 1}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
```

- [ ] **Step 8: Run the tests**

Run: `cd app && flutter test`
Expected: PASS, whole app suite.

- [ ] **Step 9: Commit**

```bash
git add app
git commit -m "feat(app): show a task's pictures, and take new ones

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```

---

### Task 13: End to end, and the README

**Files:**
- Test: `app/test/features/sync/against_real_server_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.
- Produces: a test driving the real `SyncClient` against the real server for a picture, and a README that mentions photos and the blob directory.

- [ ] **Step 1: Write the failing test**

The file's `setUp` builds the handler with a `const server.Config(...)`,
which has nowhere to put bytes. Give it a temporary directory:

```dart
  late Directory blobDir;
```

```dart
    blobDir = Directory.systemTemp.createTempSync('nemo-e2e-blobs');
    http = await shelf_io.serve(
      server.createHandler(
        db: serverDb,
        config: server.Config(
          allowSignup: true,
          webDir: '/nonexistent',
          version: '7.7.7',
          blobDir: blobDir.path,
        ),
      ),
      InternetAddress.loopbackIPv4,
      0,
    );
```

and in `tearDown`, after the database is closed:

```dart
    if (blobDir.existsSync()) blobDir.deleteSync(recursive: true);
```

Then the test itself:

```dart
  test('a picture taken here is served back by the real server', () async {
    final client = SyncClient(Dio(), baseUrl: baseUrl, token: token);
    final processed = processPhoto(smallJpeg())!;
    final clock = testClock('device');

    await client.uploadBlob(processed.sha256, processed.bytes);
    final response = await client.sync(
      SyncRequest(
        changes: [
          SyncChange.list(
            TaskList(
              id: 'l1',
              name: 'L',
              sortKey: 'V',
              updatedAt: clock.now().toString(),
            ),
          ),
          SyncChange.task(
            Task(
              id: 't1',
              listId: 'l1',
              title: 'T',
              sortKey: 'V',
              updatedAt: clock.now().toString(),
            ),
          ),
          SyncChange.photo(
            Photo(
              id: 'p1',
              taskId: 't1',
              sha256: processed.sha256,
              byteSize: processed.bytes.length,
              width: processed.width,
              height: processed.height,
              sortKey: 'V',
              updatedAt: clock.now().toString(),
            ),
          ),
        ],
      ),
    );

    expect(response.rejected, isEmpty);
    expect(await client.downloadBlob(processed.sha256), processed.bytes);
  });
```

Import `smallJpeg` from `../../support/photos.dart` and `processPhoto` from
`package:nemo/features/photos/data/photo_pipeline.dart`.

- [ ] **Step 2: Run the test to verify it fails, then passes**

Run: `cd app && flutter test test/features/sync/against_real_server_test.dart`
Expected: FAIL first if the helper does not take `blobDir`; PASS once it does. No production code should need changing here — if it does, that is a real gap, fix it and say so.

- [ ] **Step 3: Document it**

In `README.md`, extend the feature list, after the line about lists and due dates:

```markdown
- Photos on a task, taken with the camera or picked from the device, and
  synced to your other devices and to everyone a list is shared with.
```

and, in the server's configuration section, the three new settings:

```markdown
| `NEMO_BLOB_DIR` | Where photo bytes are stored | `/data/blobs` |
| `NEMO_MAX_BLOB_BYTES` | Largest single photo accepted | `5242880` |
| `NEMO_ACCOUNT_QUOTA_BYTES` | Photo storage per account | `524288000` |
```

Match the surrounding table's exact column layout; if the README documents settings as prose rather than a table, follow that instead.

If the deployment docs mount a data volume, say that the blob directory must be on it — a container that loses `/data/blobs` on restart serves 404s for every picture.

- [ ] **Step 4: Run everything**

Run:

```bash
cd packages/nemo_core && dart test
cd ../../server && dart test
cd ../app && flutter test
cd .. && dart analyze
```

Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "test(sync): a picture makes the whole round trip

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EU2VDHRHW54zjy4LwHk7ku"
```
