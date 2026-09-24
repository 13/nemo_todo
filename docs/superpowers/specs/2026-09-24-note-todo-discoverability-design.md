# Notes: make "Make todo" easy to find

## Goal

Turning selected note text into a task exists (0.12.0) but people do not
find it: on the web the browser's own context menu replaces the app's,
and the toolbar button is one icon among many. Make it visible at the
moment it applies, and teach it once. UI only.

## Decisions

| Topic | Decision |
|---|---|
| Floating chip | While the body is focused and a non-collapsed selection has `todoCandidates(value)` non-empty, an `ActionChip` "✓+ Make todo" (`Icons.add_task`) floats bottom-right just above the format toolbar; tapping it runs the same make-todo flow as the toolbar button. When the cursor (collapsed) is on a line already linked to a task, the chip reads "Open task" instead. Hidden otherwise -- including a cursor on a list line, which the toolbar button still covers: a chip on every list line being typed would be noise |
| Web right-click | While the note body has focus on the web, `BrowserContextMenu.disableContextMenu()`; re-enabled when it loses focus or the screen goes. Flutter's own menu (with "Make todo") then shows |
| One-time selection tip | The first time on a device that a non-collapsed selection with something to make (the chip showing) is made in a note body: a floating snackbar, its bottom margin clearing the toolbar and the chip, "Tip: turn selected text into a task with Make todo." with no action, normal duration. KvStore `tips.noteMakeTodo` = `'1'` once shown |
| One-time read-view hint | The first time on a device a note opens in the read view: a dismissible line above the body, "Long-press a line to make it a todo." with a close button; KvStore `tips.noteReadLongPress` = `'1'` when closed or after it has been shown once |
| Existing entry points | Unchanged: toolbar button, selection menu item, read-view long-press, "Make todo from note" row, Ctrl/Cmd+Shift+T |

## Components

- `note_detail_screen.dart`: a `ListenableBuilder` on `_body` and
  `_bodyFocus` builds the chip in a `Stack` above the toolbar (keyed
  `note-make-todo-chip`), using `todoCandidates` (selections only) /
  `linkedTaskAt` (cursor only), calling `_makeTodoFromEditor` / `_openTask`.
  `TextFieldTapRegion` around it so tapping it does not unfocus the body.
- Web context menu: in the body focus listener, `if (kIsWeb)` disable on
  focus, enable on blur and in `dispose`.
- Tips: a small `tips.dart` helper in `features/notes/ui/` with
  `Future<bool> shouldShowTip(KvStore, String key)` and `markTipShown`.
  Selection tip hooked into `_body`'s listener (first non-collapsed
  selection while focused). Read-view hint as a widget above
  `NoteReadView` (keyed `note-read-hint`).
- l10n (en/de/it): `noteMakeTodoTip`, `noteReadLongPressHint`,
  `commonClose` if missing.
  - de: "Tipp: Markierten Text mit „Als Aufgabe“ in eine Aufgabe
    verwandeln." / "Zeile lange drücken, um daraus eine Aufgabe zu
    machen."
  - it: "Suggerimento: trasforma il testo selezionato in un'attività con
    Crea attività." / "Tieni premuta una riga per farne un'attività."

## Testing

- Chip: shows for a selection with something to make; hidden for a
  cursor on a list line or plain text, for a selection with nothing to
  make, and when the body is unfocused; tapping it
  opens the make-todo sheet; on a linked line it reads "Open task" and
  opens the task.
- Tip: first selection with something to make shows it and stores the
  key; a selection with nothing to make leaves it for later; a second
  note and a second selection do not show it again. On a 360x740 phone
  with a 300 px keyboard it covers neither the chip nor the toolbar.
- Large text (2x): the line being typed stays clear of the chip.
- Read hint: shown on first read-view open, gone after close and on
  reopen.
- Web context menu: with `debugDefaultTargetPlatformOverride`/`kIsWeb`
  not controllable in tests, cover the enable/disable calls through an
  injectable callback pair (default `BrowserContextMenu` methods) and
  assert they are called on focus and blur.
