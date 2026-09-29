# Today on the home screen

## Goal

An Android home-screen widget showing Today: the open tasks due today and
the overdue ones, with their number in the header. Tapping a task opens it
in the app, tapping the header opens Today, "+" opens the app's add-task
flow, and each task's circle ticks it off without opening the app. It stays
right when tasks change (here or through sync), when the day changes and
after a reboot, and it looks like the app in light and dark. The web app is
unchanged.

## Decisions

| Topic | Decision |
|---|---|
| Plugin | `home_widget` 0.10 (compiles against SDK 35; builds with the app's AGP and compileSdk) |
| Drawing | Classic `RemoteViews` from XML, one `AppWidgetProvider` in Kotlin; no Glance composables of our own |
| Contents | Open tasks due today or earlier -- Today minus what is already done today, like the daily list |
| Order | Today's: due time, then sort key; overdue therefore first |
| Rows | Rows (up to 12) shown or hidden by the widget's height, then "+N more"; no scrolling collection |
| Size | Resizable both ways; default 3×2 cells, down to the header alone |
| Header | "Today", the count, "+" |
| Tap task | Opens `/tasks/<id>` |
| Tap header / "+N more" / empty state | Opens `/today` |
| "+" | Opens `/today` and asks for the quick-add field (the same signal as the keyboard's N / the New task button) |
| Circle | Ticks the task off in the background through the app's database and outbox; the row disappears at once |
| Day change | The app pushes a week ahead; the widget filters by the current date itself, and re-draws at the next local midnight, on a time or zone change and after boot |
| Colours | The app's current look, both brightnesses pushed: surface, text, secondary text, accent, overdue |
| Dynamic colour | Material style with the wallpaper's colours on Android 12+: the widget uses the system palette resources, so it follows a wallpaper change too |
| Dark | Follows the app's theme setting; "system" is resolved by the launcher on Android 12+ and when drawn below that |
| Strings | Native (`strings.xml`, de, it): the launcher draws without the app |

## Why this shape

### Pushing a week, filtering on the device

A widget is drawn by the launcher from data the app left behind, often long
after the app last ran. If the app pushed only "today", the list would be
wrong from midnight until the app next opened. Instead the app pushes every
open dated task due before the start of the day a week from now (overdue
ones included), each with its due instant, and the widget keeps those due
before tomorrow's start at draw time. An inexact RTC alarm at the next local
midnight re-draws it; so do `TIME_SET`, `TIMEZONE_CHANGED` and
`BOOT_COMPLETED` (alarms do not survive a reboot, so the midnight alarm is
re-armed there). This is the daily list's reasoning (see
`2026-09-28-daily-list-design.md`): overdue-ness depends only on the clock.

### Fixed rows instead of a collection

A scrolling `ListView` in a widget needs a `RemoteViewsService` and a
single `PendingIntent` template shared by every row, filled in per row. A
row with two targets -- open the task (an activity) and tick it off (a
broadcast) -- cannot have both through one template without a trampoline,
and Android 12+ blocks starting activities from a broadcast trampoline. With
plain rows every view gets its own `PendingIntent`, which is simple and
reliable. A widget showing more than a dozen tasks is a list screen anyway;
the "+N more" row opens it.

### Ticking off in the background

`home_widget`'s interactivity callback runs Dart in a headless Flutter
engine (a WorkManager job) in the app's process. The callback opens the
same SQLite file through `AppDatabase.open()` and calls
`TasksRepository.setDone` -- the very write the app makes: HLC stamp from
the stored node id and last stamp, outbox row, `hlc_last`, a repeating
task's next occurrence, the reminder cancelled, the daily list rebuilt. It
then pushes the fresh list to the widget.

Two connections may now write one file. SQLite locks the file for each
write; both connections get `busy_timeout` so the other waits instead of
failing. The app's own streams do not see another connection's writes, so
the callback posts the task id to a port named in `IsolateNameServer`; a
running app then marks the tasks, subtasks, outbox and key-value tables as
updated (screens refresh, the outbox count wakes the sync engine) and moves
its HLC past the stored stamp. With the app not running there is nobody to
tell, and the change syncs on the next start, like any offline edit.

The Flutter engine takes a second or two to start. So the widget's receiver
first records the id as pending (with the time) and re-draws without it;
the pending mark expires after 30 seconds, so a tick that failed does not
hide a task for good. Celebrations and achievement banners are the app's
and do not run for a widget tick; achievements count completions from the
data, so a tick from the widget still counts.

### Why not Glance

`home_widget` 0.10 depends on Glance, so it is on the classpath either
way, but a Compose-based widget adds a second UI toolkit to learn for
two layouts. `RemoteViews` does everything this widget needs.

## Components

### Dart, `app/lib/features/today_widget/`

- `today_widget_data.dart` -- pure. `widgetTasks(List<Task>, DateTime now)`
  keeps open tasks due before `dayStartMsFrom(now, 8)`, capped at 200,
  as `{id, title, due, timed}`; `widgetLook(...)` turns the two
  `ThemeData`s into `{mode, dynamic, light: {...}, dark: {...}}` ARGB ints.
- `today_widget_links.dart` -- the `nemo-widget://` URIs (`today`, `add`,
  `task/<id>`, `tick/<id>`) and the route each opens; "add" is
  `/today?new`.
- `today_widget_bridge.dart` -- `TodayWidgetBridge` (save a key, redraw,
  the launch URI, clicks, register the tick callback);
  `home_widget_bridge.dart` -- `HomeWidgetBridge` over `home_widget`.
- `today_widget_updater.dart` -- `TodayWidgetUpdater` encodes and saves
  `tasks` and `look`, skipping a write identical to the last, then asks for
  a redraw.
- `today_widget_providers.dart` -- `todayWidgetSyncProvider`, read by
  `NemoApp`: pushes on start, on every change to open dated tasks
  (debounced 1 s), when the style, accent, theme mode or wallpaper changes,
  and on resume; handles ticks from the widget reported by
  `todayWidgetTicksProvider`.
- `today_widget_tick.dart` -- `tickFromWidget(...)`, the testable core, and
  the `@pragma('vm:entry-point')` callback that builds its dependencies.

`today_widget_setup.dart` (`openTodayWidget`, called by `main.dart`)
registers the callback, reads the launch URI, listens to clicks -- feeding
the route into the same notifier a tapped notification uses -- and opens
the port ticks are reported to. It is a conditional import with a stub for
the web, so the web build never imports `home_widget`. `NemoApp` follows `?new` by going to Today and bumping the quick-add
request once Today is on screen.

### Android

- `TodayWidgetProvider` (`HomeWidgetProvider`): draws every instance from
  `HomeWidgetPreferences`, sizes rows from `onAppWidgetOptionsChanged`,
  arms the midnight alarm, and handles the midnight, time, zone and boot
  broadcasts.
- `TodayWidgetTickReceiver`: marks pending, redraws, then hands the URI to
  `HomeWidgetBackgroundWorker`.
- `res/layout/today_widget.xml`, `res/xml/today_widget_info.xml`,
  drawables, `values*/today_widget_colors.xml` (system palette on v31),
  strings in en, de and it.

## Localisation

Native only: `today_widget_label`, `today_widget_description`,
`today_widget_title`, `today_widget_empty`, `today_widget_more` (plural),
`today_widget_add`, `today_widget_tick`. The app's arb files get nothing new.

## Out of scope

Unticking from the widget; showing completed-today tasks; picking which
lists go in; a lock-screen or iOS widget; syncing from the background
callback (the outbox waits for the app).

## Testing

- `widgetTasks`: done, deleted and undated tasks left out; horizon of a
  week; overdue kept; order kept; cap; JSON shape.
- `widgetLook`: mode, dynamic only for Material with wallpaper colours and
  no accent, ARGB of the roles for both brightnesses.
- Links: every URI maps to its route; unknown ones map to nothing.
- `TodayWidgetUpdater` with a fake bridge: saves and redraws; an identical
  push is skipped.
- Provider with a fake bridge: pushes at start; several writes cause one
  push; changing the accent pushes the look; a tick message marks the
  tables updated so Today's stream sees another connection's write.
- `tickFromWidget` on a shared in-memory database: the task is done, the
  outbox holds it, `hlc_last` moved, a repeating task spawns its next
  occurrence, the reminder is cancelled, the widget gets the new list; an
  unknown or already-done id changes nothing.
- Not covered by tests: the Kotlin side and the headless engine, which
  need a device.
