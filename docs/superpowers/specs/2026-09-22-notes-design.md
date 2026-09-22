# Notes

## Goal

A list should be able to hold notes as well as tasks: the recipe, the
address, the packing list, the paragraph you want to keep. A note is a
title and a body of markdown, it lives in a list and so reaches everyone
that list is shared with, it can carry pictures the same way a task can,
and it syncs like every other row in nemo.

## Decisions

| Topic | Decision |
|---|---|
| What a note is | A fifth synced entity, `note`, on the existing `/sync` endpoint |
| Where a note lives | In a list, carrying `listId`, so sharing and revokes come for free |
| Body format | Raw markdown text on the wire; rendered read-only in the app |
| Pictures | The existing content-addressed blob channel, with `Photo` made parent-agnostic |
| Where notes are reached | A fifth shell destination, `/notes`, showing every note grouped by list |
| Ordering | Pinned notes first, then `sortKey` |
| Old clients | A `notes` capability flag on the sync request and response, mirroring `photos` |
| Export | Export format version 2 → 3, notes and their pictures included |

## Why this shape

A note is a row of text with a parent list. That is exactly what a task
is, minus the due date, so it gets the same treatment: row-level
last-write-wins on an HLC stamp, a tombstone rather than a delete, an
outbox entry on the device, and membership of its list as the only access
rule. Nothing new is invented for it, which is the point — the merge and
revoke behaviour is already proven by four entities.

Markdown is stored as the text the person typed. Rendering happens in the
app and nowhere else, so search still greps a string, export still writes
a string, and two devices editing the same note conflict exactly as two
devices editing a task's notes do today. A rich-text document model would
break all three.

Pictures are the interesting part. `Photo` today names a `taskId`, and a
note that can hold pictures needs that to become a parent of either kind.
Making the parent generic — `parentKind` plus `parentId` — keeps one
photos table, which matters more than it looks: the server's blob garbage
collection counts references by selecting `sha256` from that one table,
and a second attachment table would mean a second place to consult and a
new way to leak or prematurely delete bytes.

The cost is a renamed field on a synced entity and a migration of every
existing photo row on both sides. Two things contain it. First, the JSON
stays backward compatible in both directions: a task photo still emits
`task_id` alongside the new fields, and a payload carrying only `task_id`
still reads. Second, note rows and note photos are withheld from any
client that did not ask for notes, so a client old enough to be confused
by them never receives one.

## Model

`packages/nemo_core/lib/src/model/note.dart`, next to `Task`:

```dart
@freezed
abstract class Note with _$Note implements SyncRow {
  const factory Note({
    required String id,
    required String listId,
    required String title,
    @Default('') String body,     // raw markdown
    @Default(false) bool pinned,
    required String sortKey,
    required String updatedAt,    // HLC
    String? deletedAt,
  }) = _Note;

  const Note._();

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);

  bool get isDeleted => deletedAt != null;
}
```

`packages/nemo_core/lib/src/model/photo.dart` loses `taskId` and gains a
parent:

```dart
enum PhotoParent { task, note }

/// What [parentId] names. Absent on the wire from a client or server
/// released before notes, which only ever meant a task.
@Default(PhotoParent.task) PhotoParent parentKind,

/// The task or note this picture hangs on, depending on [parentKind].
/// Still spelled `task_id` on the wire, because renaming a live field
/// would break every client that has not been updated.
@JsonKey(name: 'task_id') required String parentId,
```

The *wire* keeps the name it already has: `parentId` is annotated
`@JsonKey(name: 'task_id')`, and `parentKind` serialises as `parent_kind`
with a default of `task` when the key is absent. So a task photo travels
as exactly the JSON it travels as today, a payload from before this
change reads as a task parent without any special case, and only the
Dart-side name and the new discriminator are new. A note photo does put a
note id in a field spelled `task_id`, which is the price of not renaming
a live wire field; the field carries a comment saying so, and no client
that cannot read notes is ever sent one.

Keeping the serialisation fully generated matters here: hand-written
`toJson`/`fromJson` on a freezed union member is the kind of thing that
silently drifts from the row class the next time a field is added.

## Sync protocol

`SyncEntity` gains `note`. `SyncChange` gains `SyncChange.note(Note row)`.

`SyncRequest` and `SyncResponse` each gain:

```dart
/// Whether this client can read note changes. Apps released before notes
/// throw on a change they cannot decode, which stalls their whole sync,
/// so the server only sends note changes — and photos parented to a
/// note — to clients that say they can.
@Default(false) bool notes,
```

The app holds its note changes until a response says `notes: true`, the
same way it holds photo changes today. Every response from a server that
has this change says `notes: true`, so an app learns its server was
upgraded on the very next sync.

## Server

`SyncService._apply` gains a `SyncChangeNote` case shaped like the task
case: membership of `row.listId` or `forbidden`, HLC skew check,
`incomingWins` or `_handBack`, then upsert and `logUpsert`. A note whose
`listId` changed is a move: it is revoked from the old list, and its
photos are revoked and re-logged with it, exactly as a moved task carries
its subtasks and photos.

`SyncChangePhoto` resolves its parent instead of looking up a task. The
hash validity check stays first, before any lookup:

```dart
final parent = switch (row.parentKind) {
  PhotoParent.task => await _db.taskById(row.parentId),
  PhotoParent.note => await _db.noteById(row.parentId),
};
if (parent == null) {
  return row.parentKind == PhotoParent.task ? 'unknown_task' : 'unknown_note';
}
```

`unknown_task` keeps its exact spelling, so existing clients and tests
read the same rejection they read today. Move detection compares the old
parent's list to the new parent's list; a photo re-parented from a task
to a note inside the same list is not a move and revokes nothing.

`_pull` takes `includeNotes` from the request and withholds both note
rows and photos whose `parentKind` is `note` from a client that did not
ask for them.

Cascades:

- `AccountService._deleteList` deletes the list's notes with its tasks,
  and `_handOver` hands them over with them. The photo delete that reads
  `taskId.isIn(taskIds)` becomes a match on either a task parent in
  `taskIds` or a note parent among that list's note ids. A note left
  behind would hold its blobs alive forever.
- `PurgeService` sweeps tombstoned notes past the cutoff like tasks, and
  note ids join the photo sweep so a purged note's pictures go with it.
- Blob garbage collection is untouched: it counts `photos.sha256` over
  the one photos table, which this design keeps single.
- The SSE poke needs no change — `touched` already carries the list id.
- Backup copies the whole database, so the notes table rides along.

## Storage

Both `app/lib/core/db/sync_tables.dart` and
`server/lib/src/db/sync_tables.dart` declare the identical table, because
drift cannot analyse table classes from another package:

```dart
@TableIndex(name: 'notes_list_id', columns: {#listId})
@UseRowClass(Note, generateInsertable: true)
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get sortKey => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

`Photos` replaces `taskId` with `parentKind` (text, drift enum) and
`parentId` (text). The index `photos_task_id` is replaced by
`photos_parent` on `{#parentKind, #parentId}`.

Migrations: app schema 3 → 4, server schema 4 → 5, the same steps on both
sides, inside one transaction:

1. `createTable(notes)` and its index.
2. Add `parent_kind` and `parent_id` to `photos`.
3. `UPDATE photos SET parent_kind = 'task', parent_id = task_id` — the
   backfill runs while `task_id` is still there.
4. `alterTable(TableMigration(photos))` to drop `task_id` and settle the
   defaults.
5. Create `photos_parent`, drop `photos_task_id`.

A photo row whose `task_id` is empty — which cannot happen today, but is
cheap to handle — is deleted rather than carried forward as an orphan.

Schema snapshots are regenerated with `dart run drift_dev schema dump`,
producing `app/test/generated/schema_v4.dart` and
`server/test/generated/schema_v5.dart` with their JSON, so the existing
step-by-step migration tests cover the new versions.

## App

A new feature folder, `app/lib/features/notes/`, in the shape the other
features use:

| Path | Responsibility |
|---|---|
| `data/notes_repository.dart` | Watch, create, edit, pin, move, soft-delete, search |
| `ui/notes_providers.dart` | `notesByListProvider`, `allNotesProvider`, `noteByIdProvider` |
| `ui/notes_screen.dart` | The destination: every note, grouped by list |
| `ui/note_detail_screen.dart` | Title, body, read/edit toggle |
| `ui/note_editor_sections.dart` | Pin, list picker, delete, photo strip |

Writes go through the existing `sync_writes.dart` outbox path, so a note
enqueues like any other row.

The notes screen groups by list, pinned notes first, then `sortKey`. A
row shows the title and a two-line preview of the body as plain source,
unrendered, so a long document cannot reflow the list.

The detail screen holds a title field and a body below it. Read mode
renders markdown; a pencil switches the body to a raw-text `TextField`.
Saving follows the rule `task_detail_screen.dart` already uses — on
unfocus and on pop, and never overwriting the field while it has focus —
so a half-typed note is neither lost nor fighting an incoming sync.

Routing: `Routes.notes = '/notes'` inside the `ShellRoute`, and
`Routes.note(id) = '/notes/:id'` outside it, so a note opens as a page
the way a task does. `ShellScreen.destinations` gains a fifth entry
(`Icons.sticky_note_2_outlined` / `sticky_note_2`, label `navNotes`) and
`indexFor` maps `/notes` to index 4.

The wide-window detail pane keeps showing the selected task only. Making
that pane hold either kind is a separate design problem and buys little
here.

Markdown rendering uses `flutter_markdown_plus` — the maintained fork;
`flutter_markdown` is discontinued — restricted to headings, bold,
italic, lists, links, inline code, code blocks and quotes. Raw HTML is
not rendered. Links open through the same URL launcher path the About
tile uses.

Photos on notes: `PhotoStrip` and `photos_providers` take a
`PhotoParent` and an id instead of a `taskId`, and `PhotosRepository.add`
writes the new parent columns. The capture, re-encode, EXIF-strip and
hash pipeline is untouched — a note picture is the same content-addressed
blob a task picture is.

New l10n keys, in `app_en.arb`, `app_de.arb` and `app_it.arb`:
`navNotes`, `notesEmpty`, `noteNewTitle`, `noteTitleHint`,
`noteBodyHint`, `notePinned`, `noteUnpin`, `noteDeleted`,
`noteMoveToList`, `noteEditToggle`, `noteReadToggle`,
`notePreviewEmpty`, `searchTasksHeader`, `searchNotesHeader`.
The existing `searchHint` is retouched to name notes as a place rather
than only a field of a task.

## Search

`NotesRepository.search` matches note title and body, case-insensitively,
mirroring `TasksRepository.search`. `search_screen.dart` shows tasks and
then notes, each under its own header.

## Export and import

`data_export.dart`, format version 2 → 3:

- The JSON gains a `notes` array beside `lists`, `tasks`, `subtasks` and
  `photos`, filtered to notes whose list is alive, exactly as tasks are.
- Photo selection keeps a photo whose parent is a live exported task or a
  live exported note. Bytes are still stored uncompressed under
  `photos/<sha256>`.
- Import restores notes after lists and before photos, under the rule the
  other rows follow: a row already here and alive is left alone; a
  missing or deleted one comes back with a fresh stamp.
- A version-2 file still imports. It carries no notes, and its photos
  read through the legacy `task_id` fallback.
- A version-3 file opened by an older app is refused by the existing
  version check. That is the intended behaviour.
- The import cleanup that 0.9.1 fixed now also rolls back notes written
  by a failed import, so a refusal still leaves nothing behind.

`clearLocalData` in `sync_writes.dart` drops the notes table with the
rest.

## Testing

**nemo_core.** `Note` JSON round trip. `Photo` JSON round trip for a task
parent and a note parent, and a payload carrying `task_id` with no
`parent_kind` reading back as a task parent.

**Migration.** Generated step-by-step tests for app 3 → 4 and server
4 → 5, asserting an existing photo keeps its parent across the backfill.

**Server.** A note accepted from a member and rejected as `forbidden`
from a non-member. A photo on a note in a visible list. `unknown_note`
for a photo naming a note that is not there, and `unknown_task` still
spelled that way. A note moved between lists revoking from the old list
and carrying its photos. A client with `notes: false` receiving neither
note rows nor note photos. List delete and handover taking notes with
them. Purge sweeping tombstoned notes and releasing their blobs.

**App.** The notes screen grouping by list with pinned first. Create,
edit, pin, move and delete. Markdown rendered in read mode while the
editor holds the raw source. A picture added to a note surviving a round
trip. Search finding a note by its body. Export and import round trip
with a note and its picture, and the refusal case leaving nothing behind.

Coverage floors in `ci.yml` apply to the new files like any other.

## Out of scope

- Notes outside a list, or notebooks of their own.
- Rendering HTML inside a note.
- A rich-text editor, or any document model other than markdown text.
- Showing a note in the wide-window detail pane.
- Per-paragraph merge of two edits to one note; notes merge row-level,
  last write wins, like everything else.
