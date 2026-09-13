# Photos on tasks

## Goal

A task should be able to carry photos: a picture of the broken part, the
receipt, the handwriting on the whiteboard. They are taken in the app or
picked from what is already on the device, they sync like everything else
in nemo, and they reach the other people a list is shared with.

## Decisions

| Topic | Decision |
|---|---|
| Where photos sync | Through the server, to every device and every member of a shared list |
| How rows travel | A fourth synced entity, `photo`, on the existing `/sync` endpoint |
| How bytes travel | A separate blob channel, addressed by the SHA-256 of the bytes |
| Sources | Camera and gallery, on Android and on the web |
| How many | Many per task, ordered, each one removable |
| Size | Downscaled to a longest edge of 2048 and re-encoded as JPEG q85 on the device |
| Server storage | Bytes as files on disk, metadata in SQLite |
| Download | Eagerly on Android after a pull, on demand on the web |
| Limits | 5 MB per blob, 500 MB per account, both configurable |

## Why this shape

Everything nemo syncs today is a small row of text, and the merge rules,
tombstones and revokes all assume that. A photo is neither small nor text,
and pushing base64 through `/sync` would put megabytes inside a single
write transaction that SQLite serialises against every other request.

So the row and the bytes are split. The row is a normal synced row,
indistinguishable from a subtask as far as the protocol cares, and it
carries the hash of its bytes rather than the bytes. The bytes move over
their own endpoint, which needs no merge rules at all: content addressed
by hash, a blob is immutable, so there is never a conflict to resolve, an
interrupted upload can simply be repeated, and the same photo attached to
two tasks or sent by two people is stored once.

Re-encoding on the device is what makes any of this comfortable on a home
connection: a modern phone photo is 3-8 MB and a 2048px JPEG of it is
under one. It also drops EXIF, so the location and camera serial the
camera wrote into the file never leave the device.

## Model

`packages/nemo_core/lib/src/model/photo.dart`, next to `Subtask`:

```dart
@freezed
abstract class Photo with _$Photo implements SyncRow {
  const factory Photo({
    required String id,
    required String taskId,
    required String sha256,   // of the processed bytes
    required int byteSize,
    required int width,
    required int height,
    required String sortKey,
    required String updatedAt,
    String? deletedAt,
  }) = _Photo;
}
```

`SyncEntity` gains `photo`; `SyncChange` gains `SyncChange.photo(Photo row)`
and both of its switches. A `Photos` table mirrors `Subtasks` in
`server/lib/src/db/sync_tables.dart` and `app/lib/core/db/sync_tables.dart`,
indexed on `taskId`.

Nothing about the merge changes. `incomingWins` compares `updatedAt` as it
already does, a delete is a tombstone, and a purge hands back a revoke.

## The blob channel

Two routes, mounted beside `/sync` in `server/lib/src/http/handler.dart`,
both behind the same authentication middleware:

```
POST /blobs/<sha256>   raw bytes, Content-Type: image/jpeg
GET  /blobs/<sha256>   the bytes, immutable cache headers
```

`POST` hashes what actually arrived and rejects a mismatch with 400. A
hash already on disk answers 200 without writing. Otherwise the bytes are
written to `<data>/blobs/<ab>/<cd>/<sha256>`, two levels of fan-out so no
directory grows unbounded, and a row is inserted:

```dart
class Blobs extends Table {        // server only, never synced
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();
  TextColumn get ownerUserId => text()();   // who paid for it, for quota
  IntColumn get createdAt => integer()();          // epoch milliseconds
  Set<Column> get primaryKey => {sha256};
}
```

`GET` streams the file. It is allowed when the caller is a member of some
list that holds a live photo row with that hash — the same membership
check the sync pull already does, so a revoked share loses access to the
pictures along with the tasks. A hash nobody has attached to a task the
caller can see is a 404, not a 403: the reply says nothing about whether
those bytes exist.

**Bytes before rows.** A client uploads a photo's bytes and only then
pushes its row. A photo row on the server therefore always has bytes
behind it, and no device ever pulls a row it cannot fetch. An upload that
fails leaves the row unpushed and the photo local, to be retried on the
next sync.

## Limits

A single blob over 5 MB is refused with 413. The app produces roughly a
fifth of that; the cap is there to catch a client that is not this app.
An account whose blobs already total more than its quota, 500 MB by
default, is refused with 507. Both values live in `config.dart` beside the
existing server settings.

A blob counts against the account that first uploaded it, which is who
`ownerUserId` records; a second account attaching the same photo pays
nothing, because nothing is stored for it.

The app reports either as one line — the photo is over the limit, or the
server is full — and keeps the photo locally, still attached to the task,
still shown, marked as not uploaded.

## Purge

`PurgeService` gains photos exactly as it has tasks and subtasks:
tombstoned photo rows older than the retention window are replaced by
revokes, and a purged task takes its photos with it.

Blobs are then swept separately: a blob file no live photo row references
any more, and older than the retention window, is deleted with its row.
The delay matters, because a blob is uploaded before the row that
references it and a sweep between the two would delete bytes that are
about to be claimed. `PurgeReport` gains `photos` and `blobs` counts.

## The app

### Pipeline

`features/photos/data/photo_pipeline.dart`, a pure function from bytes to
bytes so it can be tested without a camera:

```
pick or capture → decode → apply EXIF orientation → longest edge ≤ 2048
                → JPEG q85 → sha256 of the result
```

`image_picker` supplies all four routes in (camera and gallery, Android
and web), `image` does the decoding and encoding in pure Dart so the web
build works the same way. A photo already smaller than the cap is still
re-encoded, so that EXIF is dropped in every case.

### Local storage

A local-only table records what the device holds:

```dart
class BlobStore extends Table {    // app only, never synced
  TextColumn get sha256 => text()();
  IntColumn get byteSize => integer()();
  TextColumn get state => text()();   // pendingUpload | synced
  Set<Column> get primaryKey => {sha256};
}
```

On Android the bytes are a file at `<support>/photos/<sha256>.jpg`. On the
web there is no file system worth using here, and the browser may not be
the user's own: bytes live in a bounded in-memory LRU and are fetched from
the server when a photo is shown. A photo added on the web that has not
finished uploading is held in memory until it has, and is lost if the tab
is closed first; the upload starts immediately, so the window is seconds.

The split is a `PhotoStore` interface with `_io` and `_web`
implementations, selected the way `certificate_trust_adapter` already
selects one.

### Sync

Two phases wrap the existing push and pull in `sync_engine.dart`:

1. **Before the push**, every `pendingUpload` blob is uploaded, two at a
   time. A blob that lands flips to `synced`, which releases its row into
   the push.
2. **After the pull, on Android**, photo rows whose hash is not in the
   blob store are downloaded, two at a time, newest first.

Neither phase can fail the sync. An upload or download that errors is
retried on the next sync with the backoff the engine already applies.

### Screens

- **Task detail** gains a photo strip under the notes: 72px rounded
  thumbnails, scrolled horizontally, with a trailing `+` that opens a
  sheet offering *Take photo* and *Choose from gallery*. Tapping a
  thumbnail opens a full-screen pager — swipe between the task's photos,
  delete from the app bar.
- **The task tile** shows a single 40px thumbnail on its trailing edge
  when the task has photos, with a `+N` badge when there is more than one.
- **A photo whose bytes are not local yet** is a grey placeholder with an
  image glyph, never a spinner.
- **Deleting** a photo tombstones its row. The bytes are dropped once no
  live local row references that hash.

New strings go through `l10n` in all three locales.

## Testing

- `nemo_core`: photo rows merge, tombstone and revoke like subtasks.
- Server: hash mismatch refused, a second upload of the same hash writes
  nothing, quota and per-blob limits, a non-member's `GET` is a 404, the
  purge sweeps orphaned blobs but spares one newer than the window.
- App: the pipeline is deterministic — a fixed asset gives fixed
  dimensions and a fixed hash; bytes upload before their row is pushed;
  a pulled row downloads on Android and does not on the web; the strip
  and the viewer as widget tests.

## Migrations

Server database 3 → 4, creating `photos` and `blobs`. App database 2 → 3,
creating `photos` and `blobStore`.

## Out of scope

Videos, files that are not images, editing or annotating a photo, and any
server-side image processing. A photo is what the device sent.
