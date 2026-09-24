# Make Todo Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "turn selected note text into a task" findable: a floating chip at the moment it applies, the app's own right-click menu on the web, and two one-time tips.

**Architecture:** Three small widgets/helpers in `app/lib/features/notes/ui/` (chip, tips, read-view hint) wired into `note_detail_screen.dart` (already ~30 KB, so new logic goes in the new files, the screen only places them). Spec: `docs/superpowers/specs/2026-09-24-note-todo-discoverability-design.md`.

**Tech Stack:** Flutter 3.47 (fvm), Riverpod, flutter_test with `pumpApp`.

## Global Constraints

- UI only; existing make-todo entry points and behaviour unchanged.
- Chip: shown only while the body has focus, the note is in the editor, and `todoCandidates(value)` is non-empty (-> "Make todo", `Icons.add_task`, runs the screen's `_makeTodoFromEditor`) or the cursor is collapsed on a line with a task link (`linkedTaskAt`) (-> "Open task", `Icons.open_in_new`, runs `_openTask`). Key `note-make-todo-chip`. Bottom-right, just above the format toolbar. Tapping it must not unfocus the body (`TextFieldTapRegion`).
- Web only: while the note body has focus, `BrowserContextMenu.disableContextMenu()`; re-enable on blur and on dispose. Injectable for tests.
- Selection tip: first non-collapsed selection in a note body on this device -> snackbar `noteMakeTodoTip`; KvStore `tips.noteMakeTodo` = `'1'`; never again.
- Read-view hint: first time a note shows the read view on this device -> dismissible line above the body (`noteReadLongPressHint`, close button), key `note-read-hint`; KvStore `tips.noteReadLongPress` = `'1'` once shown; never again.
- Strings (en/de/it) as in the spec; `commonClose` only if it does not exist yet.
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, from `app/`; `flutter test --concurrency=2` on a directory or single file, one process at a time, 600 s timeout.
- Commit trailer: exactly the two lines in the common rules file (Opus 5.5 (1M context) + Claude-Session).
- Branch `feat/note-todo-discoverability`.

---

### Task 1: Floating chip and web context menu

**Files:**
- Create: `app/lib/features/notes/ui/make_todo_chip.dart`
- Modify: `app/lib/features/notes/ui/note_detail_screen.dart`
- Test: `app/test/features/notes/make_todo_chip_test.dart` (widget, standalone) and additions to `app/test/features/notes/note_detail_screen_test.dart`

**Interfaces:**
- Produces: `MakeTodoChip({required TextEditingController controller, required VoidCallback onMakeTodo, required ValueChanged<String> onOpenTask})` -- a `ListenableBuilder` on `controller` that renders nothing (`SizedBox.shrink`) when neither applies. `note_detail_screen.dart` gains optional constructor params for tests? No: add a top-level `browserContextMenuToggle` (`typedef void ContextMenuToggle(bool enabled)`) variable in `make_todo_chip.dart`, default calling `BrowserContextMenu.enableContextMenu()` / `disableContextMenu()` when `kIsWeb`, no-op otherwise, overridable in tests (`@visibleForTesting`).

Steps:
- [ ] Tests first:
  - `make_todo_chip_test.dart`: controller with a selection -> "Make todo" chip; tap -> `onMakeTodo` called. Cursor on `- [ ] milk` -> chip. Cursor on plain text -> nothing. Cursor on `- milk [→ task](nemo://task/t1)` -> "Open task"; tap -> `onOpenTask('t1')`.
  - `note_detail_screen_test.dart`: body focused with a selection -> `note-make-todo-chip` visible; tap it -> the make-todo sheet opens (`todo-create` found) and the body stayed focused before the sheet (the chip tap did not blur); body unfocused -> chip gone; read view -> chip gone. With `browserContextMenuToggle` replaced by a recorder: focusing the body records `false`, blurring records `true`, leaving the page records `true`.
- [ ] Implement the chip (Material 3 `ActionChip` with `avatar`, elevation 2, `TextFieldTapRegion` around it) and place it in the screen: in the bottom `Column` area, stack it bottom-right above the `NoteFormatToolbar` inside the same `ListenableBuilder(listenable: _bodyFocus)` that shows the toolbar, only when not in read view. Hook the context-menu toggle into `_onFocusChange` (body focus only) and `dispose`.
- [ ] `flutter test test/features/notes`; format, analyze.
- [ ] Commit `feat(app): offer Make todo right where text is selected in a note`.

---

### Task 2: One-time tips

**Files:**
- Create: `app/lib/features/notes/ui/note_tips.dart`
- Modify: `app/lib/features/notes/ui/note_detail_screen.dart`
- Modify: `app/lib/l10n/app_{en,de,it}.arb` (+ `flutter gen-l10n`)
- Test: `app/test/features/notes/note_tips_test.dart` and additions to `note_detail_screen_test.dart`

**Interfaces:**
- Produces: `class NoteTips { NoteTips(KvStore kv); Future<bool> shouldShow(String key); Future<void> markShown(String key); static const makeTodo = 'tips.noteMakeTodo'; static const readLongPress = 'tips.noteReadLongPress'; }`; `ReadViewHint({required VoidCallback onClose})` widget keyed `note-read-hint`.

Steps:
- [ ] Strings: `noteMakeTodoTip` (en "Tip: turn selected text into a task with Make todo."), `noteReadLongPressHint` (en "Long-press a line to make it a todo."), de/it from the spec; `commonClose` ("Close"/"Schließen"/"Chiudi") only if missing. `flutter gen-l10n`.
- [ ] Tests first:
  - `NoteTips`: `shouldShow` true until `markShown`, then false.
  - Screen: first non-collapsed selection in the body shows the tip snackbar and sets `tips.noteMakeTodo`; a second selection (and reopening the note) shows no tip. Read view (set `notes.readView` to `'1'` before opening): `note-read-hint` shows; close -> gone; reopen -> not shown. A read view opened after the key is set shows no hint.
- [ ] Implement: selection tip in `_onBodyChanged`'s neighbourhood -- a listener on `_body` that, while focused and the selection is non-collapsed, checks `NoteTips.shouldShow(makeTodo)` once per screen (guard flag), marks it shown and shows the snackbar (captured messenger). Read hint: on first build in read view, read `shouldShow(readLongPress)` once (FutureBuilder or state flag), mark shown immediately, render `ReadViewHint` above `NoteReadView` until closed.
- [ ] `flutter test test/features/notes`; format, analyze.
- [ ] Commit `feat(app): teach Make todo once, in the editor and the read view`.

---

### Task 3: Changelog and verification

- [ ] `CHANGELOG.md` `## Unreleased` -> `### Added` (create the section if the previous release renamed it), add:

```markdown
- Selecting text in a note shows a "Make todo" button right above the
  keyboard, and a one-time tip explains it; the read view says once that
  a long-press turns a line into a todo. In the web app, right-clicking
  a note's text now shows the app's menu with "Make todo".
```

- [ ] `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --concurrency=2 --exclude-tags design` -- clean, all pass.
- [ ] Commit `docs: Make todo discoverability in the changelog`.
