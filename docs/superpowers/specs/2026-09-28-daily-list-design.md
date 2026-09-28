# Daily list

## Goal

Once a day, at a time the person picks, the Android app posts one local
notification listing what is on Today: open tasks due today and overdue
ones. Nothing due means no notification. Tapping it opens Today. Fully
offline, no server changes; the web app has no daily list, as it has no
reminders.

## Decisions

| Topic | Decision |
|---|---|
| Delivery | Local notification via `flutter_local_notifications`, Android only |
| Contents | Today's open tasks plus overdue ones -- the Today screen at fire time, minus tasks already done |
| Empty day | No notification |
| Default | Off; time 08:00 |
| Settings | One "Daily list" tile: switch plus time; shown only where `remindersSupportedProvider` is true |
| Permission | Turning it on calls `ReminderScheduler.ensurePermission()`, like a task reminder |
| Channel | Own channel `daily_list` ("Daily list"), separately mutable from `reminders` |
| Title | "5 tasks today", or "3 today · 2 overdue" when some are overdue |
| Body | Collapsed: first titles joined by ", ". Expanded (inbox style): up to 6 titles, overdue first then Today's order, then "+N more" |
| Tap | Opens `/today` (`AppRoutes.today`) |
| Freshness | Precomputed: the next 7 occurrences are scheduled from current data and rebuilt on every change |
| Timing | Inexact, `allowWhileIdle`, like reminders; a few minutes late is fine |

## Why this shape

An Android notification carries fixed text, so the list has to be known
when it is scheduled. Rebuilding it whenever the data changes follows the
pattern reminders already use and needs no new plugin. A WorkManager job
at fire time would always be fresh but adds a headless isolate opening
drift and a less predictable delivery; it is left for later.

Overdue-ness only depends on the clock, so a digest built now for
Thursday is exactly right on Thursday if nothing changes in between.
Scheduling a week ahead therefore keeps the daily list arriving when the
app is not opened for a few days, instead of stopping after one. The
known gap: a change made on another device reaches this one only when
the app next syncs, so a shared list edited elsewhere can be stale in the
morning.

## Components

All under `app/lib/core/notifications/`.

### `daily_digest.dart` -- pure

```dart
class Digest {
  final int todayCount;
  final int overdueCount;
  final List<String> lines; // at most 6 titles
  final int more;           // titles not in lines
}

Digest? buildDigest(List<Task> tasks, DateTime fireAt);
```

- `tasks` are the candidates from the query below (open, dated, not
  deleted, in a list that is not deleted). `buildDigest` keeps those with
  `dueAt < dayStartMsFrom(fireAt, 1)`; overdue means
  `dueAt < dayStartMs(fireAt)`.
- Order: overdue first, then today; within each, the Today screen's due
  order (due time, then sort key).
- Returns null when no task is left.

### `daily_digest_scheduler.dart`

```dart
abstract interface class DailyDigestScheduler {
  /// Rebuilds the scheduled daily lists from [settings] and current data.
  Future<void> refresh();
}

class NoopDailyDigestScheduler implements DailyDigestScheduler { ... }

class AndroidDailyDigestScheduler implements DailyDigestScheduler {
  AndroidDailyDigestScheduler(
    this._api, {
    required Future<List<Task>> Function() loadTasks,
    required DailyListSettings Function() settings,
    required DigestStrings strings, // channel name/description, title formats, "+N more"
    DateTime Function()? now,
  });
}
```

`refresh()`:

1. Cancel ids `dailyDigestId(0..6)`.
2. If off, stop.
3. Occurrences: today at the chosen time if that is still ahead of `now`,
   otherwise tomorrow; then the following six days. Each is built as a
   local `DateTime(y, m, d, hour, minute)`, so a daylight-saving change
   keeps the wall-clock time.
4. Load candidates once; for each occurrence, `buildDigest`; schedule the
   non-null ones with id `dailyDigestId(i)`, payload `/today`.

Calls are serialised (a refresh arriving while one runs sets "go again"),
and every error is caught and logged: a failing notification never fails
a task write.

### Notification ids

Reminder ids are `taskId.hashCode & 0x7fffffff`, never negative. The
daily list uses `-1` to `-7` (`dailyDigestId(i) = -(i + 1)`), so the two
cannot collide and no existing reminder has to move.

### `NotificationsApi` changes

- `scheduleAt` gains `channelId` (default `'reminders'`), `lines`
  (`List<String>?`, shown with `InboxStyleInformation` when set) and
  `payload` (`String?`).
- `initialize` gains `onTap(String? payload)`, wired to
  `onDidReceiveNotificationResponse`; `main.dart` routes the payload with
  go_router. A launch from a tapped notification
  (`getNotificationAppLaunchDetails`) is routed the same way after start.

### Triggers

A provider holds the scheduler and calls `refresh()`:

- when a drift watch of open, dated, visible tasks emits (debounced
  ~1 s) -- this covers edits, sync, import, list deletion and restore
  without touching each call site;
- at app start and on `AppLifecycleState.resumed` (the day may have
  rolled over);
- when either setting changes.

`TasksRepository` gets `watchOpenDated()` for the watch and a one-shot
`openDated()` for `loadTasks`, both through `_visible`.

### Settings

- `KvKeys.dailyListEnabled` (`'true'`/`'false'`) and
  `KvKeys.dailyListMinutes` (minutes after midnight, default 480), read
  into `AppBootstrap` like the other settings.
- `DailyListEnabled` and `DailyListTime` controllers in
  `settings_controller.dart`, same shape as `CelebrationsEnabled`.
- Tile in the settings screen near the other notification-related
  settings: a `SwitchListTile` "Daily list", subtitle "Every day at
  08:00"; tapping the subtitle opens `showTimePicker`. When turned on and
  permission is refused, the switch stays on and the subtitle reads
  "Notifications are off for nemo" with a button opening the app's system
  notification settings.

## Localisation

New en/de/it keys: `dailyListTitle`, `dailyListSubtitle` (time
placeholder), `dailyListPermissionOff`, `dailyListChannelName`,
`dailyListChannelDescription`, `dailyListToday` (plural count),
`dailyListTodayOverdue` (two counts), `dailyListMore` (count).

## Out of scope

Web; a background (WorkManager) refresh or sync before firing; picking
which lists go in; a "Nothing due today" notification; weekdays-only
schedules.

## Testing

- `buildDigest`: empty gives null; counts for today and overdue; a
  task done, deleted or in a deleted list is left out; ordering overdue
  first; cap at 6 lines with `more`; a task due tomorrow appears only in
  tomorrow's digest; an all-day task (no time) counts as today.
- `AndroidDailyDigestScheduler` with a fake `NotificationsApi` and a
  fixed clock: off cancels all seven and schedules none; time already
  passed today starts tomorrow; empty days are skipped; a DST-change day
  keeps 08:00 local; payload and channel are set; a refresh during a
  refresh runs once more, not in parallel; an api error is swallowed.
- Trigger provider: several task writes in quick succession cause one
  refresh; changing the time causes one.
- Settings tile widget tests: hidden when unsupported; switch persists;
  time picker persists; permission refused shows the hint.
