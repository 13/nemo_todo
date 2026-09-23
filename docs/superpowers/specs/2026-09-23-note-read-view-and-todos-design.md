# Notes: read view toggle, and turning notes into todos

## Goal

Two additions to the note screen, both UI only -- the model, database,
sync, server and export are untouched:

1. **Read view.** A button in the note's app bar switches the body between
   the live markdown editor (as today) and a formatted read view with the
   markers hidden. Tapping the read view's text goes back to editing.
2. **Make todo.** A selection, a line, or the whole note becomes one or
   more tasks through a short confirm sheet. The note keeps its text and
   gains a link to each task it produced.

## Decisions

| Topic | Decision |
|---|---|
| Read view vs 0.11.0 | 0.11.0 dropped the read/edit toggle and `flutter_markdown_plus`. The editor stays the default and stays always-editable; the read view is an opt-in second mode, rendered by our own parser, not the package |
| Toggle | `IconButton` in the app bar, left of the pin. Icon `visibility_outlined` in the editor ("Formatted"), `edit_outlined` in the read view ("Markdown") |
| Mode remembered | Last mode used, device-local in `KvStore` (key `notes.readView`), not synced. A note with an empty body always opens in the editor |
| Read view taps | Checkbox: flips `[ ]`/`[x]` in the body and saves. Web link: opens (http/https only, via `openUrlProvider`). Task link: opens the task. Anything else: switches to the editor, cursor at the start of the tapped line |
| Title | Stays an editable field in both modes |
| Todo entry points | Editor toolbar button and selection context menu; read view long-press on a line; a "Make todo from note" row at the bottom of the note page beside the list picker and delete |
| Confirm | Bottom sheet, prefilled, one tap to create |
| Note afterwards | Text kept; a task link appended per produced task |
| Link format | `[→ task](nemo://task/<id>)` -- plain markdown, so search, export and merge are unaffected |
| Two-way sync | None. Ticking the task does not tick the note's box or vice versa; the read view's chip shows the task's live state instead |
| Duplicates | A line already carrying a task link offers "Open task" instead of "Make todo" |

## Why this shape

The notes and markdown-editor designs keep `Note.body` a plain markdown
string and avoid any edit the person did not make, because every write
syncs and two devices must not fight over a note. Both features respect
that: the read view only writes when a checkbox is tapped, and make-todo
writes exactly once, as one edit, when the person confirms. Linking rather
than moving keeps the note's context intact and makes it visible which
lines are already tasks; auto-ticking would be a write nobody made.

The read view reuses the editor's parser so both modes agree on what is
markdown. `flutter_markdown_plus` would render more (tables, images) but
cannot map a rendered checkbox back to a source offset, which the tap to
tick needs, and it would disagree with the editor at the edges.

## Part A: read view

### `markdown/note_read_view.dart`

`NoteReadView({required String body, required ValueChanged<String>
onChanged, required ValueChanged<int> onEditAt, required ValueChanged<int>
onLongPressLine})`

- Splits the body into lines with their source offsets (pure function
  `readLines(String body) -> List<ReadLine>`, `ReadLine(start, end, kind)`
  where `kind` is `task(checked)`, `bullet`, `numbered`, `heading(level)`,
  `quote`, `rule`, `codeBlock`, `text`). A fenced block is one `ReadLine`.
- Each line renders as one widget:
  - task: a real `Checkbox` plus the content as rich text; checked content
    struck and muted.
  - bullet / numbered: indented, `•` or the number, then content.
  - heading: full editor sizes (`headlineSmall`..`titleSmall`), bold.
  - quote: left border in `outlineVariant`, italic, muted.
  - rule: `Divider`.
  - codeBlock: monospace on `surfaceContainerHighest`, rounded, fences
    hidden, horizontally scrollable.
  - blank line: a half-height gap.
- Inline content uses the span builder behind `markdownPreviewSpan`,
  refactored so it can style a sub-range of the body without the preview's
  heading cap (`markdownInlineSpan(text, base, theme, {capHeadings})`).
  Web links get a `TapGestureRecognizer`; task links render as a
  `TaskLinkChip` (Part B).
- Checkbox tap: `toggleTaskAt(body, lineStart) -> String` (pure) and
  `onChanged` with the new body.
- Tap elsewhere on a line: `onEditAt(lineStart)`.
- Long-press on a line: `onLongPressLine(lineStart)`.

### Note screen

- `_readView` bool state, initialised from `KvStore` (false when the body
  is empty). The toggle flushes a pending body edit through the existing
  save path before switching, writes the mode to `KvStore`, and swaps the
  body `TextField` for `NoteReadView`.
- `onChanged` from the read view goes through the same save path as the
  editor (controller text set, immediate save rather than debounce).
- `onEditAt(offset)`: switch to the editor, set the selection to
  `offset`, request focus.
- The format toolbar only shows in the editor, as today.

## Part B: make todo

### `markdown/note_to_task.dart` (pure Dart)

```dart
/// A line's text with its list/task marker and markdown removed.
String plainLine(String line);

/// A stretch of the body to become a task, and where its link goes.
class TodoCandidate {
  const TodoCandidate({required this.title, required this.anchor});
  final String title;
  final int anchor; // offset the task link is inserted at
}

/// What "Make todo" acts on for this editor value: the selection split
/// into lines (blank and ticked-checkbox lines dropped), or, with no
/// selection, the list/task line under the cursor. Empty when there is
/// nothing to act on.
List<TodoCandidate> todoCandidates(TextEditingValue v);

/// The candidate for one line of the body, for the read view's long-press.
TodoCandidate? lineCandidate(String body, int lineStart);

/// The task id already linked on the line containing [offset], if any.
String? linkedTaskAt(String body, int offset);

/// [body] with ` [→ task](nemo://task/<id>)` inserted at each anchor,
/// applied from the last anchor backwards so earlier offsets stay valid.
String insertTaskLinks(String body, List<(int anchor, String id)> links);

/// [body] with the links to [ids] removed again, for undo.
String removeTaskLinks(String body, Set<String> ids);

/// The whole note as one candidate: title from the note title, the body as
/// task notes, and its unticked checkbox lines as possible subtasks.
({String title, String notes, List<String> checklist}) wholeNote(Note n);
```

Anchor: end of the line for a whole-line candidate; end of the selection
for a selection within a single line; for the whole note, a new final line
(`\n[→ task](nemo://task/<id>)`).

### `make_todo_sheet.dart`

`showMakeTodoSheet(context, {required List<TodoCandidate> candidates,
required String listId, WholeNote? wholeNote}) -> Future<MakeTodoResult?>`

- Modal bottom sheet, `MaxWidth` 720.
- One candidate: title `TextField` (prefilled, autofocus off), list
  dropdown (note's list; Inbox if that list no longer exists), due-date
  chip (existing date picker), priority chip, Create.
- Several candidates: a `SegmentedButton` -- "One task per line"
  (default; lists the titles) or "One task with subtasks" (title field
  prefilled with the first line, the rest as subtasks). List, date and
  priority apply to all tasks.
- Whole note: title prefilled from the note title, body into task
  `notes`, and when the body has unticked checkboxes a "Checklist becomes
  subtasks" switch (default on).
- Create returns the chosen shape; the caller does the writes.

### Creating

In the note screen (one helper, `_makeTodo(candidates, {wholeNote})`):

1. `tasksRepository.create(...)` per task; `subtasksRepository.add` per
   subtask.
2. Body becomes `insertTaskLinks(body, ...)`, saved through the existing
   save path as one edit (one undo step in the editor).
3. Snackbar: "Task created" / "N tasks created", actions Open (single task
   only; `Routes.task(id)`) and Undo (delete the tasks, then
   `removeTaskLinks` on the current body and save).

### Entry points

- **Editor toolbar:** `add_task` button "Make todo", enabled when
  `todoCandidates(value)` is non-empty. When `linkedTaskAt` finds a link at
  the cursor, it becomes "Open task" (`open_in_new`), like "Open link".
- **Editor selection menu:** a "Make todo" item added through the body
  field's `contextMenuBuilder`, shown when the selection is non-empty.
- **Read view long-press:** a small menu at the line with "Make todo" (or
  "Open task" when linked) and "Edit".
- **Whole note:** a `ListTile` "Make todo from note" (`add_task`) between
  `NoteListPicker` and `NoteDeleteAction`.
- **Keyboard:** Ctrl/Cmd+Shift+T runs the toolbar action.

### Task links

- Router: `nemo://task/<id>` maps to `Routes.task(id)`. The editor's "Open
  link" and the read view both use one helper, `openNoteLink(context, ref,
  url)`, which routes task links in-app and sends http/https to
  `openUrlProvider` as today; anything else is ignored.
- `TaskLinkChip(taskId)` in the read view watches `taskByIdProvider`:
  outlined `task_alt` while open, filled `check_circle` when done,
  `outline` colour and "Task deleted" tooltip when gone. The chip shows
  the task's current title, truncated. Tap opens the task.
- In the editor, card previews and search rows the link is ordinary
  markdown: faint markers, link text `→ task`.

## Localisation

New keys in en/de/it: `noteReadToggle` ("Formatted"), `noteEditToggle`
("Markdown"), `noteMakeTodo` ("Make todo"), `noteMakeTodoFromNote` ("Make
todo from note"), `noteOpenTask` ("Open task"), `noteTodoPerLine` ("One
task per line"), `noteTodoWithSubtasks` ("One task with subtasks"),
`noteTodoChecklistSubtasks` ("Checklist becomes subtasks"),
`noteTodoCreate` ("Create"), `noteTodoCreated` (plural: "Task created" /
"{count} tasks created"), `noteTaskDeleted` ("Task deleted").

## Error handling

- A failed save after a checkbox tap or link insertion shows the existing
  save-failure state and keeps the text, as the editor does.
- If creating a task fails part way, the tasks already created are
  deleted, the body is left unchanged, and a snackbar says so.
- A task link whose task is missing still opens the task route, which
  already shows not-found.

## Testing

- Unit (`note_to_task_test.dart`, `note_read_view_lines_test.dart`):
  `plainLine` over every marker kind; `todoCandidates` for a word
  selection, a multi-line selection with blank and ticked lines, a cursor
  on a list line, a cursor on plain text (empty); `insertTaskLinks` with
  several anchors keeps offsets right; `removeTaskLinks` restores the
  original body; `linkedTaskAt`; `readLines` kinds and offsets including
  unclosed fences; `toggleTaskAt`.
- Widget: toggle switches modes and the choice survives reopening; a
  checkbox tap in the read view saves the flipped body; a text tap enters
  the editor with the cursor on that line; the sheet in single, per-line,
  subtasks and whole-note forms creates the right tasks and subtasks and
  inserts links; Undo removes both; the chip follows the task's done
  state; a linked line offers "Open task".
