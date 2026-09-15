# Maintenance: dependency updates

## Goal

Bring the build's dependencies up to date without changing what the app does:
the two open Dependabot pull requests, and `file_picker`'s new major version.

## Decisions

| Topic | Decision |
|---|---|
| Docker Dart image (PR #4, `dart:3.13.2-sdk` → `3.13.3-sdk`) | Merged as Dependabot opened it: it only touches `Dockerfile`, and its CI passed |
| GitHub Actions (PR #5) | Not rebased; the same bumps are applied in our own commit, and Dependabot closes its PR once `main` carries them |
| `actions/checkout` | `@v5` → `@v7` (ci.yml ×2, release.yml ×2) |
| `actions/setup-java` | `@v5` → `@v6` (ci.yml ×1, release.yml ×1) |
| `actions/upload-artifact` | `@v5` → `@v7` (ci.yml ×1) |
| `file_picker` | `^12.3.0` → `^13.0.0` |
| Branch | `chore/maintenance`, merged into `main` locally; pushing and GitHub actions (merging PR #4, closing PR #5) only with the user's go-ahead |

## Why this shape

PR #5 was opened before this week's change to `ci.yml` (the daylight saving
test step sits in the region it edits), so rebasing it means resolving a
conflict inside a generated PR. Applying three version numbers ourselves is
simpler and reviewable, and Dependabot notices the update and closes its PR.

`file_picker` 13 is a major version, but its breaking changes do not reach
this app. They are:

- `PlatformFile.length()` now returns `Future<int?>`. The app never calls it.
- Parameters deprecated since 12.0 were removed: `allowMultiple`, `withData`,
  `withReadStream`, `readSequential`, `lockParentWindow`,
  `cancelUploadOnWindowBlur` and `androidSafOptions`. The app passes none of
  them.

The app calls only `FilePicker.saveFile(fileName:, bytes:, mimeType:)`,
`FilePicker.pickFile(type:, allowedExtensions:)` and
`PlatformFile.readAsBytes()`, all unchanged in 13.0.0.

## Verification

- Workflow files parse as YAML, and CI passes on the pushed commit. The
  `upload-artifact` bump is exercised by CI's build job; release.yml's bumps
  run on the next tag.
- `flutter pub get` resolves `file_picker 13.0.0`, and the import and export
  tests (`test/features/settings/data_tiles_test.dart`,
  `data_export_test.dart`) and the full suite pass. `flutter analyze` is
  clean.
- After the merge, `gh pr list` shows neither Dependabot PR open.
