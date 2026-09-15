# Photos in export

## Goal

An export restores a device completely, pictures included. Today it writes
lists, tasks and subtasks, and a restored task comes back without its photos.

## Decisions

| Topic | Decision |
|---|---|
| File | Always a `.zip` named `nemo-<yyyy>-<mm>-<dd>.zip` |
| Contents | `nemo-export.json` (format `nemo-export`, version 2: v1's `lists`, `tasks` and `subtasks`, plus `photos`), and the picture bytes as `photos/<sha256>` |
| Which photos | Live photos on exported tasks whose bytes this device holds; the rest are left out and counted |
| Old exports | Import still reads a version-1 `.json` file |
| Version 2 on an old app | Refused as "not a nemo export": the old app reads the zip as JSON and fails before writing anything |
| Import of a photo | Only for a live task, and only when the photo is not already alive here; the bytes must hash to the row's `sha256`, otherwise that photo is skipped |
| Import order | `store.put` → `store.pin` → `rememberBlob(pendingUpload)` → `upsertPhoto`, the order a newly added photo uses, so sync uploads bytes before the row |
| Zip library | `archive` (already resolved at 4.3.0 through `image`), made a direct dependency |
| Picker | Save as `application/zip`; open accepts `zip` and `json` |
| Strings | Export hint no longer says photos are left out; the export message says how many photos were left out, when any were |
| Backlog | The "Photos in an export" entry is removed |

## Why this shape

A zip keeps a single file for people to save, and stores each picture by its
hash, the same key the photo store and the server use. Always including
photos makes a backup complete by default; one format and one button are
simpler than an option that decides whether a backup is complete.

Writing the JSON as its own entry keeps the existing export and import logic
intact. Parsing, merge rules ("a live row here wins, a missing or deleted one
comes back with a fresh stamp") and the version check stay where they are;
version 2 only adds the `photos` list.

A photo whose bytes are not on this device can happen on the web, where
bytes are fetched on demand and evicted. It is left out rather than failing
the export, and the message says so, so the person knows the backup is
partial.

Import puts the bytes before the row, and marks them pending upload, for the
same reason adding a photo does: a row that reaches the server before its
bytes shows as a broken picture on every other device.

## Changes

- **`app/lib/features/settings/data/data_export.dart`:**
  - `export` returns an `ExportResult` holding the zip bytes and the number
    of photos left out. It reads the bytes from the `PhotoStore`.
  - `import` takes the picked bytes and accepts a zip or a v1 JSON text.
  - `version` becomes 2.
  - The constructor takes the `PhotoStore`.
- **`app/lib/features/settings/ui/data_tiles.dart`:**
  - saves `.zip` with `application/zip`;
  - opens with `allowedExtensions: ['zip', 'json']`;
  - passes the bytes straight to `import`;
  - shows the photos-left-out message when the count is above zero;
  - builds `dataExportProvider` with `photoStoreProvider`.
- **`app/pubspec.yaml`:** adds `archive: ^4.3.0`.
- **ARB strings in en, de and it:**
  - `settingsExportHint` now says lists, tasks, subtasks and photos, as a
    zip file;
  - new `settingsExportedWithoutPhotos(count)`.
- **`docs/backlog.md`:** removes the "Photos in an export" entry.
- **`CHANGELOG.md`:** an `### Added` bullet under `## Unreleased`.

## Limits

The zip is built in memory. A device with hundreds of photos (each at most
about 1 MB after processing) uses tens of megabytes while exporting, which is
acceptable for the household scale nemo is built for.

## Testing

`app/test/features/settings/data_export_test.dart`, over an in-memory
database and `MemoryPhotoStore`:

- **Export:** the zip holds `nemo-export.json` (version 2, with the photo
  row) and `photos/<sha>` with the exact bytes.
- **Round trip to a fresh device:** tasks and photos come back. Each
  photo's bytes are in the store and pinned, recorded `pendingUpload`, and
  the row is queued in the outbox.
- **Bytes not on this device:** the photo is left out, counted in
  `ExportResult`, and absent from the zip.
- **Old file:** a version-1 `.json` still imports.
- **Tampered picture:** an entry whose bytes do not match its hash is
  skipped, and the rest of the import succeeds.
- **Photo on a deleted task:** it is not imported.
- **Importing twice:** the second import adds nothing.
- **Not an export:** refused before any row or byte is written, whether
  garbage bytes, a zip without `nemo-export.json`, or version 3.

Widget test in `data_tiles_test.dart`: the export saves a `.zip`, and the
message mentions photos left out when some are.
