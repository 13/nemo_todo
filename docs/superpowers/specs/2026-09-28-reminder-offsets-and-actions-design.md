# Reminder offsets and actions

## Goal

A task can have several reminders, each chosen from presets relative to
its due time ("1 day before", "15 min before", "at due time"). Each
reminder notification carries Done and Snooze buttons that work without
opening the app. Reminders stay synced across devices, as `remind` is
today. Android only, as today.

Builds on the daily list (`2026-09-28-daily-list-design.md`): all-day
tasks are reminded at the daily list's time, so that spec lands first.

## Decisions

| Topic | Decision |
|---|---|
| Model | New synced field `reminders: List<int>`, minutes before due; `0` = at due time |
| Old `remind` | Kept; written as `reminders.isNotEmpty`; read as `[0]` when `reminders` is empty and `remind` is true |
| Timed presets | At due time, 5, 15, 30 min, 1 h, 2 h, 1 day, 2 days, 1 week before |
| All-day presets | That morning, 1 day, 2 days, 1 week before (`0`, `1440`, `2880`, `10080`) |
| All-day anchor | Daily list time (`KvKeys.dailyListMinutes`, default 08:00) on the local due date, minus whole days |
| Custom offsets | No |
| Without a due date | No reminders, as today; clearing the due date clears them |
| Buttons | Done, Snooze 10 min, Snooze 1 h -- all without opening the app |
| Tap on the notification | Opens the task |
| Snooze | Device-local, not synced; a second snooze replaces the first |
| Background Done | Same as ticking it off in the app: HLC-stamped, repeating tasks roll on; no celebration |
| Sync of a background Done | With the next ordinary sync |

## Why this shape

A list of offsets on the task covers both "before due" and "several
reminders" with one field, and keeps reminders synced the way the single
flag is. Keeping `remind` beside it means an app that has not been updated
yet still sees that a task reminds; it may, when it edits such a task,
reset the offsets to "at due time", which is acceptable for a household
that updates together and is called out in the changelog.

Snoozing is about this phone right now, not about the task, so it stays
out of the synced row.

Done has to change the database from a background isolate, because the
point of the button is not opening the app. `setDone` already does
everything a tick needs (stamping, repeat, reminder upkeep), so the
background path builds a `TasksRepository` and calls it rather than
writing rows itself.

## Components

### Model and schema

- `packages/nemo_core`: `Task` gains `@Default(<int>[]) List<int>
  reminders`, JSON key `reminders`. A getter `effectiveReminders` returns
  `reminders`, or `[0]` when that is empty and `remind` is true. Writers
  set `remind: reminders.isNotEmpty`.
- `server`: `tasks.reminders` text column, default `'[]'`, schema 6 → 7;
  migration sets `'[0]'` where `remind = 1`. Sync reads and writes it like
  the other columns.
- `app`: same column in `app_tables.dart`, schema 5 → 6, same migration;
  the task converter maps JSON text ↔ `List<int>`.
- Export/import carries `reminders`; importing an old export without it
  falls back to `remind` through `effectiveReminders`.

### `reminder_presets.dart`

```dart
const timedPresets = [0, 5, 15, 30, 60, 120, 1440, 2880, 10080];
const allDayPresets = [0, 1440, 2880, 10080];

/// When the reminder at [offset] minutes before [task]'s due fires, or
/// null if it cannot (no due date).
DateTime? reminderFireAt(Task task, int offset, {required int anchorMinutes});
```

Timed: `dueAt − offset`. All-day: the local due date at `anchorMinutes`
after midnight, minus `offset ~/ 1440` days, built as a local `DateTime`
so daylight-saving changes keep the wall-clock time. An all-day task
carrying a sub-day offset (set while it had a time) is treated as `0`;
the scheduler drops duplicate fire times, so `[0, 15]` on an all-day task
posts one notification.

### `AndroidReminderScheduler`

- `notificationId(taskId, offset)` = `"$taskId:$offset".hashCode &
  0x7fffffff`; `snoozeId(taskId)` = `"$taskId:snooze".hashCode &
  0x7fffffff`. Non-negative, so clear of the daily list's `-1..-7`. The
  0.14 id (`taskId.hashCode & 0x7fffffff`) is cancelled on every sync so an
  upgraded reminder never fires twice.
- `effectiveReminders` is `remind ? (reminders.isEmpty ? [0] : reminders)
  : []`: `remind` stays the switch, and every writer uses
  `withReminders(list)`, which sets both.
- `sync(task)`: cancel the ids of every timed preset and the snooze id;
  if `wantsReminder` (now: `effectiveReminders` not empty, open, not
  deleted, dated), schedule each offset whose fire time is still ahead.
- Payload: `Routes.task(id)`, so a plain tap opens the task through the
  daily list's tap routing and an action reads the id back from it; actions `done`, `snooze10`,
  `snooze60`, each `showsUserInterface: false`, `cancelNotification:
  true`.
- Body by distance from fire time to due: "Due now", "Due in 15 min",
  "Due today at 14:30", "Due tomorrow", "Due on Fri 3 Oct".
- Needs the anchor: reads it from the daily list settings through a
  function passed in, like `now`.
- `snooze(task, Duration)`: schedules `snoozeId` at now + duration with
  the same title, body "Snoozed", same buttons.
- When the daily list time changes, the daily list's refresher re-syncs
  every open, dated task, since all-day fire times move. Import keeps its
  existing re-sync pass.

### `NotificationsApi` changes

On top of the daily list's (`channelId`, `lines`, `payload`, `onTap`):

- `scheduleAt` gains `actions: List<NotificationAction>` (a small
  app-owned type: id and label), mapped to `AndroidNotificationAction`.
- `initialize` gains `onBackgroundResponse`, a top-level function,
  passed as `onDidReceiveBackgroundNotificationResponse`.
- Foreground responses with an action id go to the same handler as the
  background ones; a plain tap routes to the task.

### `reminder_actions.dart`

```dart
@pragma('vm:entry-point')
void onReminderActionInBackground(NotificationResponse r);

/// Shared by the foreground and background paths.
Future<void> handleReminderAction(
  ReminderAction action,
  String taskId, {
  required TasksRepository tasks,
  required AndroidReminderScheduler reminders,
});
```

- Background entry: `WidgetsFlutterBinding.ensureInitialized()`, open
  `AppDatabase` (shared across isolates), `AppBootstrap.load` for node id
  and last HLC, initialise notifications and time zones, build the
  scheduler and repository, call `handleReminderAction`, close the
  database.
- `done`: `tasks.setDone(taskId, done: true)`. Missing, deleted or
  already done: nothing.
- `snooze10` / `snooze60`: `reminders.snooze(task, ...)`. Missing or done:
  nothing.
- If the database cannot be opened in the background (for instance a
  migration is due after an update), post a plain notification for the
  task that opens it, so the tap is not lost.

### Database sharing and the clock

`AppDatabase` opens with `DriftNativeOptions(shareAcrossIsolates:
true)`, so a background isolate and the running app use one connection
instead of two writers on one file, and the app's streams see the
background write. Every task write already persists `hlc_last`; on
`AppLifecycleState.resumed` the app's `HlcClock` takes in the persisted
value (`receive`), so its next stamp is never behind a background one.

### Task sheet

The "Remind me" switch becomes a "Reminders" row (`Key('task-reminders')`)
with a summary ("At due time, 1 day before" / "None"). Tapping opens a
bottom sheet of `FilterChip`s for the presets that fit the task (timed or
all-day); each change saves and asks for permission the first time, as
the switch does. Disabled without a due date, with the existing
unavailable subtitle off Android. Clearing the due date (detail sheet and
reschedule sheet) sets `reminders: []`.

## Localisation

New en/de/it keys: `remindersRow`, `remindersNone`, preset labels
(`remindAtDue`, `remindMinutesBefore`, `remindHoursBefore`,
`remindDaysBefore`, `remindWeekBefore`, `remindThatMorning`), bodies
(`remindDueNow`, `remindDueIn`, `remindDueTodayAt`, `remindDueTomorrow`,
`remindDueOn`, `remindSnoozed`), actions (`remindActionDone`,
`remindActionSnooze10`, `remindActionSnooze60`). `remindersDueNow` is
replaced by `remindDueNow`.

## Out of scope

Custom offsets; reminders without a due date; other snooze lengths;
synced snoozes; web; celebrations for a background Done.

## Testing

- Core: `reminders` JSON round-trip; `effectiveReminders` with legacy
  `remind`; `remind` written as `isNotEmpty`.
- Server and app migrations: `remind = 1` rows get `'[0]'`, others
  `'[]'`; syncing a row from an old client without `reminders` keeps
  working.
- `reminderFireAt`: timed offsets; all-day at the anchor minus days;
  a DST-change day keeps the anchor time; sub-day offset on an all-day
  task treated as `0`.
- `AndroidReminderScheduler` with a fake api and fixed clock: one
  notification per future offset, past ones skipped; ids distinct per
  offset and non-negative; sync cancels every preset id and the snooze
  id; done/deleted/undated cancels everything; actions and payload set;
  body text per case; `resyncAll` after an anchor change moves all-day
  reminders.
- `handleReminderAction` on an in-memory database: Done ticks off,
  stamps and persists the HLC, spawns the next repeat with its reminders
  scheduled, and cancels this task's others; snooze schedules at +10 and
  +60 min and replaces an earlier one; missing or done task does nothing.
- Widget: Reminders row summary; chip toggles save; all-day task shows
  only day presets; clearing the due date clears reminders; disabled
  without a due date.
- Manual, on a device: Done and Snooze from the notification with the app
  killed and with it open; the task list updates when the app is open.
