# Selecting Several Tasks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Select several tasks on any task-listing screen and complete, delete or move them to another day at once.

**Architecture:** One keep-alive Riverpod notifier holds the selection (a set of task ids, or null when not selecting). `TaskTile` and `TaskListSlivers` read it to change what a tap does and to switch swipes and drag off. `StyleScaffold` gains an opt-in flag that adds the **Select** action and swaps in a `SelectionBar` (bottom on narrow windows, top on wide). Bulk actions live beside the single-task ones and reuse the reschedule sheet's day picker.

**Tech Stack:** Flutter, flutter_riverpod with riverpod_annotation codegen, drift, gen-l10n (en/de/it), flutter_test with `test/support/pump_app.dart`.

**Spec:** `docs/superpowers/specs/2026-11-18-multi-select-tasks-design.md`

## Global Constraints

- "Move" means another day only; no list change, no other bulk edits.
- Long press, swipe and drag keep their current meaning outside selection.
- Bulk delete, bulk move and bulk done each show **one** snackbar with Undo for the whole selection, `persist: false`, as the single-task snackbars do.
- Bulk done celebrates once, not once per task.
- Every new string exists in `app_en.arb`, `app_de.arb` and `app_it.arb`.
- Generated files (`*.g.dart`, `app_localizations*.dart`) are regenerated, never hand-edited: `cd app && dart run build_runner build -d` and `flutter gen-l10n`. The pre-commit hook rejects stale ones.
- Run tests from `app/`: `flutter test <path>`. Analyzer clean: `flutter analyze`.

## Review Focus

1. A selected task leaves the screen while selecting (ticked on another device, synced away): the count and the actions only cover tasks still on screen. Test in Task 1 (`retainVisible`) and Task 3.
2. A mix of done and open tasks selected: **Done** marks the open ones done and leaves the done ones alone; only an all-done selection is marked undone. Test in Task 3.
3. A repeating task completed in bulk still spawns its next occurrence (it goes through `TasksRepository.setDone`). Test in Task 3.
4. Undo tapped after the screen is gone: the snackbar's action uses the repository captured before the write, never `ref`. Test in Task 3 (navigate away, then tap Undo).
5. Shift-click with no earlier click to range from: selects just that task. Test in Task 1.

---

### Task 1: The selection state

**Files:**
- Create: `app/lib/features/tasks/ui/task_selection.dart` (+ generated `task_selection.g.dart`)
- Test: `app/test/features/tasks/task_selection_test.dart`

**Interfaces:**
- Produces: `taskSelectionProvider` (`@Riverpod(keepAlive: true) class TaskSelection`, state `Set<String>?`; null = not selecting, empty set = selecting with nothing picked). Methods:
  - `void start()` — state becomes `{}` if null.
  - `void toggle(String id)` — starts selection if needed; adds or removes `id`; records `id` as the range anchor.
  - `void extendTo(String id, List<String> visibleIds)` — selects every id between the anchor and `id` inclusive, in `visibleIds` order, adding to the selection; with no anchor, or an anchor not in `visibleIds`, behaves as `toggle(id)`.
  - `void retainVisible(Iterable<String> ids)` — drops selected ids not in `ids`; does nothing when not selecting; does not notify when nothing was dropped.
  - `void end()` — state null, anchor cleared.

- [ ] **Step 1: Write the failing tests** using a bare `ProviderContainer`:
  - `start` from null gives `{}`; `end` gives null.
  - `toggle('a')` from null gives `{'a'}`; again gives `{}` (still selecting, not null).
  - `toggle('b')` then `extendTo('d', ['a','b','c','d','e'])` gives `{'b','c','d'}`; `extendTo('a', …)` from anchor `'b'` adds `'a'` (ranges work upward).
  - `extendTo('c', [...])` with no anchor gives `{'c'}` (Review Focus 5).
  - `retainVisible(['a'])` on `{'a','b'}` gives `{'a'}`; on null stays null.
- [ ] **Step 2: Run** `flutter test test/features/tasks/task_selection_test.dart` — expect FAIL (file missing).
- [ ] **Step 3: Implement** `TaskSelection` in `task_selection.dart`, following `selected_task.dart`'s style (doc comments say what, not how). Anchor is a private field on the notifier. Run `dart run build_runner build -d`.
- [ ] **Step 4: Run** the test — expect PASS. `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(tasks): a selection of several tasks`

### Task 2: Rows while selecting

**Files:**
- Modify: `app/lib/core/widgets/task_tile.dart` (build, `_TileBody`'s `InkWell` and `DoneCheck`)
- Modify: `app/lib/features/tasks/ui/task_list_view.dart` (`_plain`, `_reorderable`, `_dismissible`, the build that writes `visibleTasksProvider`)
- Test: `app/test/features/tasks/task_selection_rows_test.dart`

**Interfaces:**
- Consumes: `taskSelectionProvider` from Task 1.
- Produces: row key `Key('select-task-${task.id}')` on the leading selection indicator, so later tests can find it.

Behaviour:
- While `taskSelectionProvider` is non-null: tapping a row calls `toggle(task.id)` instead of `openTask`; Shift-tap calls `extendTo(task.id, <visible ids>)`; the round `DoneCheck` is replaced by a selection indicator (filled check circle in the accent when selected, empty ring otherwise, keyed as above, with `Semantics(checked: …)`); a selected row is highlighted with `context.nemoColors.selection` (macOS: the same accent treatment the open task gets); `Dismissible` is not built (return the child directly) and `ReorderableDelayedDragStartListener` is not built; long press does nothing.
- Outside selection, on a pointer device: ⌘-tap (macOS) or Ctrl-tap (others) calls `toggle(task.id)`, Shift-tap calls `extendTo`, entering selection. Read modifiers from `HardwareKeyboard.instance` in `onTap`. A plain tap still calls `openTask`.
- `TaskListSlivers` calls `retainVisible` with the ids it lists, after the frame, whenever it writes `visibleTasksProvider` (Review Focus 1).

- [ ] **Step 1: Write the failing widget tests** with `pumpApp` and two or three tasks due today (seed as `test/screens/app_shortcuts_test.dart` does):
  - `app.container.read(taskSelectionProvider.notifier).start()`, pump, tap a title: `taskSelectionProvider` contains its id, no task page opened (`find.byType(TaskDetailScreen)` finds nothing), and its `select-task-…` indicator shows.
  - While selecting, dragging a row sideways (as `task_swipe_test.dart` does) leaves the task undone.
  - Ctrl-tap (`tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft)` around the tap) on a wide window (`Size(1400, 900)`) starts selection with that id; Shift-tap on the third selects the first three.
  - Not selecting: a plain tap still opens the task (existing behaviour).
- [ ] **Step 2: Run** `flutter test test/features/tasks/task_selection_rows_test.dart` — expect FAIL.
- [ ] **Step 3: Implement** the behaviour above.
- [ ] **Step 4: Run** the new test, then `flutter test test/features/tasks test/a11y test/screens` — all PASS (swipe, reorder and semantics tests unchanged).
- [ ] **Step 5: Commit** `feat(tasks): rows toggle into a selection instead of opening`

### Task 3: The selection bar and its actions

**Files:**
- Create: `app/lib/features/tasks/ui/bulk_actions.dart`
- Create: `app/lib/features/tasks/ui/selection_bar.dart`
- Modify: `app/lib/features/tasks/ui/reschedule_sheet.dart` (extract the picker)
- Modify: `app/lib/core/widgets/style_scaffold.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`
- Test: `app/test/features/tasks/selection_bar_test.dart`

**Interfaces:**
- Consumes: `taskSelectionProvider` (Task 1); `visibleTasksProvider`, `completeTask`, `tasksRepositoryProvider`.
- Produces:
  - `Future<({DateTime? day})?> pickRescheduleDay(BuildContext context, WidgetRef ref, {DateTime? current, required bool canClear})` in `reschedule_sheet.dart` — the existing sheet's body; `showRescheduleSheet` now calls it. Keys `reschedule-today|tomorrow|next-week|pick|clear` unchanged.
  - In `bulk_actions.dart`, each taking `(BuildContext context, WidgetRef ref, List<Task> tasks)` and returning `Future<void>`: `completeTasks`, `rescheduleTasks`, `deleteTasksWithUndo`. Each ends the selection (`end()`) after its write.
  - `class SelectionBar extends ConsumerWidget` — count text, **Done**, **Move**, **Delete**, **Cancel** (keys `selection-done`, `selection-move`, `selection-delete`, `selection-cancel`). Acts on selected tasks that are in `visibleTasksProvider`, in on-screen order. Buttons disabled when that list is empty. Done's icon/label is "undone" when every selected task is done.
  - `class SelectAction extends ConsumerWidget` — top-bar icon button (`Icons.checklist_rounded`, tooltip `l.selectTasks`, key `select-tasks`) calling `start()`.
  - `StyleScaffold({…, bool taskSelection = false})`: when true, `SelectAction` is appended to both `appBar` actions (non-Material; rebuild the `AppBar` via `copyWith`-equivalent or accept `actions` on both paths) and Material `actions`; while selecting, on a window narrower than `ShellScreen.splitBreakpoint` the `bottomNavigationBar` is the `SelectionBar` and the FAB is hidden; on a wider one the `SelectionBar` replaces the top bar (`PreferredSize`, height `kToolbarHeight`) and the bottom bar stays.

Action semantics (from the spec):
- `completeTasks`: if every task is done, mark all undone via `repo.setDone(id, done: false)`; otherwise mark only the open ones done — `repo.setDone(id, done: true)` for all but the last, `completeTask(ref, last, done: true, showPill: false)` for the last, so the celebration fires once. Snackbar `l.tasksCompletedMany(n)` / `l.tasksUndoneMany(n)` with Undo reversing exactly the tasks changed.
- `rescheduleTasks`: `pickRescheduleDay(current: null, canClear: tasks.any((t) => t.dueAt != null))`; apply to each task as `showRescheduleSheet` does (keep a time of day it has; clearing also clears `dueHasTime` and `remind`); snackbar `l.rescheduleMovedMany(n, when)` (when = `dueLabel` of the day without time) or `l.rescheduleClearedMany(n)`; Undo saves each task's original `dueAt`, `dueHasTime`, `remind`.
- `deleteTasksWithUndo`: `repo.delete` each; snackbar `l.tasksDeletedMany(n)`; Undo `repo.restore` each.
- Read the repository and `ScaffoldMessenger` before the first write; Undo uses only those (Review Focus 4).

Strings (ICU plurals, `count` is `int`, `when` is `String`):

| key | en | de | it |
|---|---|---|---|
| `selectTasks` | Select | Auswählen | Seleziona |
| `selectionCount` | `{count} selected` | `{count} ausgewählt` | `{count, plural, =1{1 selezionata} other{{count} selezionate}}` |
| `tasksCompletedMany` | `{count, plural, =1{1 task done} other{{count} tasks done}}` | `{count, plural, =1{1 Aufgabe erledigt} other{{count} Aufgaben erledigt}}` | `{count, plural, =1{1 attività completata} other{{count} attività completate}}` |
| `tasksUndoneMany` | `{count, plural, =1{1 task not done} other{{count} tasks not done}}` | `{count, plural, =1{1 Aufgabe wieder offen} other{{count} Aufgaben wieder offen}}` | `{count, plural, =1{1 attività riaperta} other{{count} attività riaperte}}` |
| `tasksDeletedMany` | `{count, plural, =1{1 task deleted} other{{count} tasks deleted}}` | `{count, plural, =1{1 Aufgabe gelöscht} other{{count} Aufgaben gelöscht}}` | `{count, plural, =1{1 attività eliminata} other{{count} attività eliminate}}` |
| `rescheduleMovedMany` | `{count, plural, =1{Moved 1 task to {when}.} other{Moved {count} tasks to {when}.}}` | `{count, plural, =1{1 Aufgabe auf {when} verschoben.} other{{count} Aufgaben auf {when} verschoben.}}` | `{count, plural, =1{1 attività spostata a {when}.} other{{count} attività spostate a {when}.}}` |
| `rescheduleClearedMany` | `{count, plural, =1{Removed the date from 1 task.} other{Removed the date from {count} tasks.}}` | `{count, plural, =1{Datum von 1 Aufgabe entfernt.} other{Datum von {count} Aufgaben entfernt.}}` | `{count, plural, =1{Data rimossa da 1 attività.} other{Data rimossa da {count} attività.}}` |

Cancel uses the existing `commonCancel`.

- [ ] **Step 1: Write the failing widget tests** on Today (`pumpApp`, seed three tasks due today, one of them a weekly repeat, plus one already done today). Today's screen gets `taskSelection: true` in this task so the bar is reachable (other screens in Task 4).
  - Tap `select-tasks`, tap two titles: `'2 selected'` shows. Tap `selection-done`: both done in `app.db`, `'2 tasks done'` shows, selection ended (`taskSelectionProvider` null). Tap Undo: both open again.
  - Repeat task among those done: a new open row with the same title exists afterwards (Review Focus 3).
  - Select one open and the done one, tap `selection-done`: open one becomes done, done one stays done (Review Focus 2). Select only done ones: they become open.
  - Select two, `selection-move`, `reschedule-tomorrow`: both `dueAt` equal `dayStartMsFrom(testNow, 1)` (or keep their time), `'Moved 2 tasks to Tomorrow.'` shows; Undo restores original `dueAt`.
  - Select two, `selection-delete`: `'2 tasks deleted'`, both have `deletedAt`; go to another destination (`tester.tap` the Upcoming nav item), tap Undo: both restored (Review Focus 4).
  - Select two, then delete one through a `TasksRepository` on `app.db` (as another device's sync would): count drops to `'1 selected'` (Review Focus 1).
  - `selection-cancel`: selection null, quick-add bar back.
  - Existing `tag_and_reschedule_test.dart` long-press reschedule still passes (picker extraction).
- [ ] **Step 2: Run** `flutter test test/features/tasks/selection_bar_test.dart` — expect FAIL.
- [ ] **Step 3: Implement** the picker extraction, `bulk_actions.dart`, `selection_bar.dart`, the `StyleScaffold` flag, the strings (`flutter gen-l10n`), and `taskSelection: true` on `TodayScreen`. Selection bar follows the app style: Material uses `BottomAppBar`/`AppBar` with icon buttons and labels; nemo and macOS use the look of their existing bars (see `QuickAddBar`, `macos_theme.dart`).
- [ ] **Step 4: Run** `flutter test` (whole app suite) — PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(tasks): complete, move or delete several tasks at once`

### Task 4: Every task screen, the keyboard, and ending a selection

**Files:**
- Modify: `app/lib/features/tasks/ui/upcoming_screen.dart`, `app/lib/features/tasks/ui/tag_screen.dart`, `app/lib/features/tasks/ui/search_screen.dart`, `app/lib/features/lists/ui/list_detail_screen.dart` — `taskSelection: true` on their `StyleScaffold` (search: wherever its scaffold is built; if it is not a `StyleScaffold`, add `SelectAction` and the bar the same way).
- Modify: `app/lib/screens/shell_screen.dart` (`go`), `app/lib/core/widgets/style_scaffold.dart` (end on dispose)
- Modify: `app/lib/screens/app_shortcuts.dart`
- Modify: `CHANGELOG.md` (`## Unreleased` → `### Added`)
- Test: `app/test/screens/app_shortcuts_test.dart`, `app/test/features/tasks/selection_bar_test.dart`

**Interfaces:**
- Consumes: `taskSelectionProvider` (Task 1), `completeTasks`, `deleteTasksWithUndo` (Task 3).

Behaviour:
- Selection ends when the shell changes destination (`go` calls `end()` beside `select(null)`) and when a `StyleScaffold` with `taskSelection: true` is disposed (capture the notifier in `initState`; make the scaffold a `ConsumerStatefulWidget`).
- `AppShortcuts`, while `taskSelectionProvider` is non-null: Space runs `completeTasks` on the selected visible tasks, Delete/Backspace runs `deleteTasksWithUndo`, Escape runs `end()` (and does not also clear the open task). Arrow keys and j/k unchanged. Shortcuts help (`showShortcutsHelp`) lists the three, with new strings only if the help names actions in prose — reuse `selectTasks`/existing labels otherwise.
- CHANGELOG entry, user-facing: "Select several tasks at once — Select in the top bar, or ⌘/Ctrl- and Shift-click — and mark them done, move them to another day or delete them together."

- [ ] **Step 1: Write the failing tests:**
  - In `app_shortcuts_test.dart`: wide window, Ctrl-tap both errands, press Space: both done; select both again, press Delete: both deleted, one snackbar; select one, press Escape: selection null, nothing deleted.
  - In `selection_bar_test.dart`: start selecting on Today, tap the Upcoming destination: `taskSelectionProvider` null. Open a list's page, `select-tasks` shows there; select and go back: selection null.
- [ ] **Step 2: Run** both files — expect FAIL.
- [ ] **Step 3: Implement** the behaviour above and the CHANGELOG entry.
- [ ] **Step 4: Run** `flutter test` and `flutter analyze` — all PASS / clean.
- [ ] **Step 5: Commit** `feat(tasks): select on every task screen and from the keyboard`
