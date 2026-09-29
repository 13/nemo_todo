# Share into nemo

## Goal

On Android, nemo appears in the system share sheet. Sharing text, a link
or pictures from another app opens a small "New task" sheet in nemo,
prefilled from what was shared; the user picks the list, edits, and saves
or cancels. Works offline and without an account, like everything else.
The web build is unchanged.

## Decisions

| Topic | Decision |
|---|---|
| What is accepted | `ACTION_SEND` with `text/plain` or `image/*`; `ACTION_SEND_MULTIPLE` with `image/*` |
| Plugin | None: a small in-app Flutter plugin class (`ShareIntake.kt`) on a `MethodChannel`, registered from `MainActivity` |
| Why not a plugin | `receive_sharing_intent` 1.9.0 compiles against API 37; 1.8.1 and `share_handler` 0.0.25 build with AGP 7/8 era scripts, and none of them hands over `EXTRA_SUBJECT`, which is what a browser puts the page title in |
| Instances | `MainActivity` becomes `singleTask`, so a share reaches the running app through `onNewIntent` rather than starting a second engine (and a second database connection and sync engine) inside the sharing app's task |
| Title | `EXTRA_SUBJECT` when given; else the first non-empty line of the text, cut at 120 characters on a word boundary |
| Notes | The text, when a subject took the title; else the lines after the first; the whole text when the first line had to be cut |
| A lone link | Becomes the title and also goes into the notes, so it survives a title edit and stays tappable in the notes |
| Pictures | Held as bytes in the sheet; on save each goes through `PhotosRepository.add`, the same path as the camera and gallery (re-encoded on device, EXIF dropped). Bytes that are not a picture are skipped with the existing `photosNotAnImage` snackbar |
| Only pictures, no text | Title empty; Save stays disabled until one is typed |
| Quick add | `parseQuickAdd` runs on the title at save, as in the quick-add bar: `#tags`, `!high`, a trailing date word |
| List | Inbox preselected; a menu of all lists |
| Cancel | Closes the sheet; nothing is written |
| After saving | Snackbar `shareTaskAdded` ("Added to {list}") |
| A share while the sheet is open | Queued; shown after the open sheet closes |
| Relaunch from recents | An intent carrying `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY` is not a new share and is ignored |
| Web, other platforms | `NoShareSource`: nothing arrives, nothing is registered |

## Components

### Android

- `AndroidManifest.xml`: `launchMode="singleTask"` and one extra
  `<intent-filter>` block on `MainActivity` for the three action/type
  pairs above.
- `ShareIntake.kt`: a `FlutterPlugin` + `ActivityAware` +
  `NewIntentListener`. On attach it reads the launch intent; on a new
  intent it reads that one. Text and subject are read on the main thread,
  picture bytes from the content resolver on a background thread (a file
  larger than 25 MB is skipped). Channel `dev.ben.nemo/share`:
  - Dart → native `initial`: the share that started the activity, once,
    or null.
  - native → Dart `shared`: a share arriving while running.
  - Payload: `{text: String?, subject: String?, images: List<Uint8List>}`.
- `MainActivity.kt`: `configureFlutterEngine` adds the plugin. Nothing
  else, so another change to the activity merges easily.

### Dart: `app/lib/features/share/`

- `data/shared_content.dart`: `SharedContent` (text, subject, images) and
  `ShareDraft` (title, notes, images), and `ShareDraft.from(content)` --
  the title and notes rules above, pure and unit-tested.
- `data/share_source.dart`: `ShareSource` (`Future<SharedContent?>
  initial()`, `Stream<SharedContent> incoming`), `ChannelShareSource`
  over the channel, `NoShareSource`; `shareSourceProvider` picks the
  channel on Android and nothing elsewhere. Tests override it with a fake.
- `ui/share_task_sheet.dart`: the sheet. Title field (quick-add hint),
  notes field, thumbnails of the pictures with a button to leave one out,
  list chip, Cancel and Save. Save creates the task through
  `TasksRepository.create`, then adds each picture through
  `PhotosRepository.add(PhotoParent.task, ...)`, and pops `true`.
- `ui/share_receiver.dart`: `ShareReceiver`, placed in `NemoApp`'s
  builder. Asks the source for the initial share after the first frame,
  listens for later ones, and shows the sheet with `showAppSheet` on the
  router's root navigator.

## Localisation

New en/de/it key `shareTaskAdded` ("Added to {list}" / "Zu {list}
hinzugefügt" / "Aggiunta a {list}") and `shareRemovePhoto` ("Leave out
this picture" / "Dieses Bild weglassen" / "Escludi questa immagine").
The sheet's other words already exist (`shortcutNewTask`,
`tasksTitleHint`, `tasksNotesHint`, `tasksList`, `listsInbox`,
`commonSave`, `commonCancel`).

## Testing

- `ShareDraft.from`: subject wins; a lone URL goes to title and notes;
  multi-line text splits; a long single line is cut and kept whole in the
  notes; whitespace-only text gives an empty draft; pictures pass through.
- `ChannelShareSource` against a mocked channel: `initial` decodes the
  map, null stays null, a `shared` call reaches `incoming`.
- Sheet (widget, over the test database): prefilled fields; Save creates
  the task in the Inbox with quick-add parsing applied (`#tag !high
  tomorrow`) and the notes; a picked list is used; Cancel writes nothing;
  pictures end up as the task's photos through the pipeline (re-encoded,
  so the stored hash differs from the shared bytes); a non-picture is
  skipped with the snackbar; Save disabled while the title is empty.
- `ShareReceiver` inside `NemoApp` with a fake source: an initial share
  opens the sheet at start; a share while running opens it; a second one
  while the sheet is up waits for it.

Untested off a device: the manifest filters, the Kotlin class, reading
`content://` URIs from real apps, and `singleTask` behaviour.
