# Test gaps

## Goal

Test the code that ships without tests, and give `nemo_core` headroom above
its CI coverage floor.

## Decisions

| Topic | Decision |
|---|---|
| Counted as gaps | Code with behaviour and no test: `NemoApp` (`app/lib/app.dart`), `SecureAuthStorage`, `LocalNotificationsApi`, and the uncovered lines in `nemo_core` |
| Not counted | Drift table declarations (`app_tables.dart`, `sync_tables.dart`), freezed model declarations (`app_release.dart`), one-line conditional exports, and `main.dart` (platform startup, exercised by the startup error screen and the real-server test) |
| App wiring test | Pumps the real `NemoApp` with the same overrides `pumpApp` uses, rather than `pumpApp`'s copy of its wiring |
| Secure storage | Tested through `FlutterSecureStorage.setMockInitialValues` |
| Notifications | Tested through the plugin's test seam if one exists; otherwise dropped, with the reason recorded in the plan |
| Production code | Unchanged, apart from test seams only if a plan task proves one necessary |

## Why this shape

Coverage numbers count declarations that never "run" (drift's table DSL,
freezed factories), so a 0% there says nothing. The real gaps are:

- `NemoApp`. Every widget test builds its own `MaterialApp` in `pumpApp`,
  copied from `NemoApp`, so a change to the real wiring goes unnoticed. That
  wiring covers the router's first screen, the auth guard, the celebration
  overlay in `builder`, the session restore, and the sync and update checks
  at start.
- `SecureAuthStorage`, where the session token lives. Only its in-memory
  twin is tested.
- `LocalNotificationsApi`, the adapter from reminders to the plugin.
- `nemo_core`, measured at 90.7% by CI's tool against a 90% floor. Its
  uncovered lines are `Hlc.hashCode`, one branch of `HlcClock.receive` (local
  clock ahead of both wall time and the remote stamp), the `hashCode` and
  `toString` of the three `Repeat` kinds, and `Task.repeatRule`.

## Tests

- **`app/test/app_test.dart`, real app:**
  - Local-first (`authRequired` false): opens on Today, titles itself "nemo
    todo", mounts the celebration overlay, follows a stored dark theme, and
    has restored the session.
  - Web-style (`authRequired` true) with no stored session: lands on the
    sign-in screen.
  - Updates are marked unsupported in both, so the start-up check makes no
    network call.
- **`app/test/features/auth/auth_storage_test.dart`:** `SecureAuthStorage`
  reads a stored token, writes one, and deleting (writing null) removes it.
  All three go through the plugin's in-memory mock.
- **`app/test/core/notifications/notifications_api_test.dart`:**
  `scheduleAt`, `cancel` and `initialize` reach the plugin with the expected
  id, instant and channel, through its platform test seam.
- **`packages/nemo_core/test`:**
  - equal `Hlc`s share a `hashCode` and act as one set entry;
  - `receive` counts on from the local stamp when the local clock is ahead of
    both;
  - each `Repeat` kind's `toString` names its encoding, and equal rules hash
    equally;
  - `Task.repeatRule` parses a known rule and yields null for an unknown one.
