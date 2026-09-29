# Reminders on the web

## Goal

A task's reminder and the daily list show up as browser notifications in
the web app, as long as a nemo tab is open somewhere in that browser.
Server push stays out (`docs/backlog.md`), so nothing arrives with every
tab closed, and the app says so where reminders are switched on.

## Decisions

| Topic | Decision |
|---|---|
| Mechanism | `new Notification()` from the page, at times kept by Dart timers |
| Interface | The existing `NotificationsApi`; a web implementation, `TimedNotifications` |
| Schedulers | The Android ones, unchanged in shape: `AndroidReminderScheduler`, `AndroidDailyDigestScheduler` |
| Where it runs | Desktop browsers with the Notifications API; not where the constructor is refused (Chrome on Android phones -- they have the app) |
| Tab closed | Nothing; the next load fires what was missed in the last 10 minutes |
| Missed older than that | Dropped, never a burst of stale reminders |
| Twice | A fired log in `localStorage` (shared by the origin's tabs) and a per-notification `tag` |
| Permission | Asked only from a gesture: the task's Remind switch, the daily list switch, Allow in Settings |
| Denied | Settings and the Remind switch say the browser blocks it; no prompt is attempted |
| Click | Focuses the tab, closes the notification, opens the task (`/tasks/<id>`) |
| Done / Snooze buttons | Not on the web (see below) |
| Daily list | Same mechanism; fires at its time while a tab is open, not caught up on load |
| Service worker | None added |
| CSP | Unchanged; the icon is same-origin, nothing is fetched or evaluated |

## Why this shape

The schedulers already turn tasks into "show this at that instant"
calls. Giving the web its own `NotificationsApi` keeps every rule --
which tasks remind, the daily list's text and ids, cancelling on done --
in one place for both platforms. What differs is only who keeps the
schedule: Android's alarm manager keeps it across reboots, the page keeps
it in memory. So the web side has two extra duties: rebuild the schedule
every time the page loads, and decide what to do about times that passed
while no page was open.

A reminder is about now. Ten minutes late still helps; a morning of
reminders fired at once when the laptop is opened at noon does not. The
window applies both on load and to a timer that fires late because the
machine slept.

### Service worker and actions

Notification actions (Done, Snooze) exist only on notifications posted
through `ServiceWorkerRegistration.showNotification`; the page's
`Notification` constructor throws when given any. The Flutter build ships
no working service worker: since Flutter dropped its PWA caching,
`flutter_service_worker.js` only unregisters itself, and the server's
static handler serves it like any other file. Adding one of our own is
allowed by the CSP (`worker-src 'self' blob:`), but it would buy little:
a service worker cannot open the drift database the page holds, so Done
would have to message an open page -- which exists by definition here,
and is one click away. Android does not have the buttons yet either
(`2026-09-28-reminder-offsets-and-actions-design.md` is still to come).

So: no service worker, no buttons. Clicking a notification opens the task,
where it is ticked off. When the offsets spec lands, the web gets its
offsets for free through the scheduler; buttons would be a separate
decision to add a worker.

## Components

### `BrowserNotifications` (thin interop)

`browser_notifications.dart` holds the interface; the web version, in
`browser_notifications_web.dart`, is the only file touching
`package:web`, and is chosen by a conditional export like the splash's.

```dart
enum BrowserPermission { granted, denied, ask }

abstract interface class BrowserNotifications {
  ValueListenable<BrowserPermission> get permission;
  Future<BrowserPermission> requestPermission();
  void show({required String tag, required String title,
             required String body, required void Function() onClick});
  void close(String tag);
}

abstract interface class FiredLog {
  String? read();
  void write(String value);
}
```

- `openBrowserNotifications()` returns null where `Notification` is
  missing (and always off the web).
- `permission` re-reads `Notification.permission` whenever the tab
  becomes visible again, which is when someone comes back from the
  browser's site settings.
- `show` sets `icon` to the app icon and the notification's `onclick` to
  `window.focus()`, `close()`, then `onClick`. A constructor that throws
  is logged, not rethrown.
- `FiredLog` on the web is one `localStorage` key, wrapped in try/catch;
  elsewhere, memory.

### `TimedNotifications implements NotificationsApi`

- Keeps pending notifications by id; `scheduleAt` replaces, `cancel`
  removes and closes a shown one with that id's tag.
- One timer, armed for the earliest pending time but never longer than an
  hour (under `setTimeout`'s limit, and a cheap re-check after sleep).
  Each tick shows everything due, then re-arms.
- A due notification is shown when it is no more than `missedWindow` (10
  min) late, permission is granted, and its key (`id@epochMs`) is not in
  the fired log. Showing adds the key; keys older than a day are pruned.
- `lines` become the body, one per line.
- `initialize(onTap:)` keeps the tap handler; a click hands it the
  payload. `launchPayload` is always null.
- Clock and timer are injected, so tests run on a fake timeline.

### Reminder scheduler

- `AndroidReminderScheduler` gains `missedWindow` (default zero): a task
  still wants its reminder until that long after it was due, so a page
  loading just after the due time still schedules it -- and the api shows
  it at once.
- Its notifications carry the payload `/tasks/<id>`, so a click on the
  web and a tap on Android open the task through the existing
  `notificationRouteProvider`.

### Keeping the page's schedule current

Writes in this tab already call `ReminderScheduler.sync`, and so does the
sync engine for what it pulls. What they miss is the start of the page
and writes from another tab of the same browser, which reach this tab only
through the database's streams. `ReminderResync` listens to
`watchOpenDated()` (open, dated, not deleted, list not deleted), syncs
every task in each emission and cancels any that dropped out since the
last one. It is read by `NemoApp` and does nothing unless
`remindersInPageProvider` is true (the web). The daily list keeps its own
refresher, which already follows the same stream.

### Settings and the task sheet

- `remindersSupportedProvider` is true on the web when the browser has
  notifications.
- On the web, Settings shows a "Notifications in this browser" row above
  the daily list: its state (on / asks / blocked / unsupported), the
  sentence that they arrive only while a nemo tab is open, and Allow while
  the browser would still ask.
- The Remind switch's subtitle says the browser blocks notifications when
  it does.

## Localisation

New en/de/it keys: `browserNotificationsTitle`, `browserNotificationsOn`,
`browserNotificationsAsk`, `browserNotificationsAllow`,
`browserNotificationsBlocked`, `browserNotificationsUnsupported`,
`tasksRemindBlocked`. `tasksRemindUnavailable` no longer says Android
only.

## Out of scope

Server push; a service worker; Done and Snooze buttons; catching up a
daily list missed while no tab was open; notifications on mobile
browsers.

## Testing

- `TimedNotifications` on a fake clock and timer with a fake browser:
  fires at the time; replacing and cancelling; a far-off time re-arms in
  hour steps; missed within the window fires on schedule, older does not;
  a late timer (sleep) past the window does not; the fired log stops a
  second tab or a reload firing again; no permission, nothing shown;
  click passes the payload; cancel closes a shown one; lines join.
- `AndroidReminderScheduler`: payload is the task route; `missedWindow`
  keeps a just-due task scheduled.
- `ReminderResync`: syncs each task, cancels ones that left.
- Widgets: the Settings row in each permission state and Allow asks;
  the Remind switch's blocked subtitle.
- Manual, in desktop Chrome: set a reminder a minute ahead, switch tabs,
  click the notification; reload just after a due time.
