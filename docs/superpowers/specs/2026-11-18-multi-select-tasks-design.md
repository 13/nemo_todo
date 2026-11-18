# Selecting several tasks — design

Short design: a small change.

## Intent

Complete, delete, or move to another day several tasks at once, instead of
one at a time through the menu, a swipe or a key.

## Goals

- Select several tasks on any screen that lists them: Today, Upcoming, a
  list's page, a tag, search.
- Act on the selection: **Done**, **Move** (to another day), **Delete**.
- Works on phone and desktop.

## Non-goals

- Moving tasks to another list (decided: "move" means another day).
- Editing other fields in bulk (priority, tags, list).
- Selection surviving a change of screen.

## Anti-goals

- Changing what a long press, a swipe or a drag does today.
- Losing a task with no way back: bulk delete and bulk move offer undo as
  their single-task versions do.

## Approaches

- **A. Select button plus modifier-clicks (picked).** A **Select** action in
  the screen's top bar enters selection; on desktop ⌘/Ctrl-click toggles a
  task and Shift-click selects a range, entering selection directly.
  Nothing existing changes meaning; one extra tap to start on a phone.
- B. Long press enters selection where rows cannot be reordered. Familiar
  gesture, but long press would mean different things on different
  screens and loses its reschedule shortcut.
- C. Long press enters selection everywhere, reordering moves to a drag
  handle. Most consistent, but rewrites reordering, its accessibility
  actions and tests.

Picked A: it keeps every existing gesture and behaves the same on every
screen.

## Decided

- Entry: **Select** in the top bar of each task-listing screen; on desktop,
  ⌘/Ctrl-click and Shift-click.
- In selection, tapping a row toggles it instead of opening it; each row
  shows a check state. Swipes and drag are off while selecting.
- A bar shows the count and **Done · Move · Delete**, plus a way to cancel.
- Move reuses the reschedule sheet's choices (today, tomorrow, next week,
  pick a date, no date), applied to every selected task; each keeps its
  own time of day.

## Builder's calls (proposals, correctable)

- **Done** marks all selected done; if every selected task is already done
  it marks them undone, mirroring the single-task toggle.
- Bulk done celebrates once, not per task, and shows one snackbar with undo.
- Bulk delete and bulk move each show one snackbar with undo for the whole
  selection.
- Selection lives in one keep-alive provider (a set of task ids) beside
  `selectedTaskProvider`; it clears on screen change, on Cancel, on Escape,
  and after an action. Ids no longer on screen are dropped.
- Keyboard while selecting: Space = Done, Delete/Backspace = Delete,
  Escape = cancel. Arrow keys keep moving the single open task.
- The selection bar sits at the bottom on a phone and in the list's top bar
  on desktop; macOS and Material styles each draw it in their own look.
- New strings in en, de and it.
- Widget tests for entering selection, toggling, range select, each action
  and undo.
