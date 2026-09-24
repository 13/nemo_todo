# Pull down to sync

## Goal

On Android (and touch screens in the web app), pulling down on a list runs
a sync, the way people expect from mail and chat apps. UI only: the sync
engine, server and protocol are unchanged.

## Decisions

| Topic | Decision |
|---|---|
| Screens | Today, Upcoming, Lists, a list's tasks, Notes, a tag's tasks, Search results |
| Mechanism | One shared `SyncRefresh` widget wrapping each screen's scrollable, built on Material `RefreshIndicator` |
| No account | Gesture off (`SyncStatus.local`): no indicator, nothing happens |
| Spinner | Stays until the sync has finished; if one is already running, waits for that one |
| Short / empty screens | Still pullable (always-scrollable physics, empty states inside a scrollable) |
| Success | No message |
| Offline | Snackbar: existing `settingsOffline` ("Offline. Changes will sync when you are back online.") |
| Other error | Snackbar: new `syncPullFailed` ("Sync didn't work. It will try again shortly.") |
| Signed out | Snackbar: new `syncPullSignedOut` ("Your session has ended. Sign in again in Settings.") |
| Desktop mouse | No pull gesture there; Settings' "Sync now" remains |

## Why this shape

`SyncEngine.syncNow()` already does a full push and pull and reports the
outcome in `SyncState.status`, so the pull only has to call it and read
the status afterwards. A wrapper per screen keeps the gesture tied to that
screen's own vertical list; one indicator around the shell would also hear
nested and horizontal scrolls (format toolbar, photo strips).

`syncNow()` returns at once when a run is already in progress (it only
marks "go again"), so the wrapper waits for the status to leave `syncing`
rather than trusting the returned future alone.

## Components

### `app/lib/features/sync/ui/sync_refresh.dart`

```dart
class SyncRefresh extends ConsumerWidget {
  const SyncRefresh({required this.child, super.key});
  final Widget child; // a vertical scrollable
}
```

- Watches `syncEngineProvider`. When `status == SyncStatus.local`, returns
  `child` unchanged.
- Otherwise returns `RefreshIndicator(key: Key('sync-refresh'), onRefresh:
  _refresh, child: child)`.
- `_refresh`: captures the notifier and `ScaffoldMessenger` first; calls
  `syncNow()`; then, if the status is still `syncing`, waits for the next
  state that is not `syncing` (listening via `ref.listenManual` or the
  container, with a 60 s safety timeout); then shows the snackbar for
  `offline`, `error` or `signedOut`, nothing for `idle`.
- `RefreshIndicator` only reacts to overscroll, so each wrapped scrollable
  uses `AlwaysScrollableScrollPhysics` (combined with its existing physics
  via `parent:`).

### Screens

Wrap the main vertical scrollable of each screen:

- `TaskListView` (`features/tasks/ui/task_list_view.dart`) -- used by
  Today, Upcoming, list detail and tag: wrap its `CustomScrollView` and give
  it always-scrollable physics. One change covers four screens.
- `ListsScreen`, `NotesScreen` (grid `CustomScrollView`), `SearchScreen`
  (its results list).
- Empty states on these screens (`EmptyState`) are shown instead of the
  list; wrap them so they can be pulled: a `LayoutBuilder` +
  `SingleChildScrollView(physics: AlwaysScrollableScrollPhysics())` +
  `ConstrainedBox(minHeight: constraints.maxHeight)` around the empty
  state, inside `SyncRefresh`. A small helper
  `SyncRefresh.scrollable(child)` builds that, so screens do not repeat it.

## Localisation

New en/de/it keys: `syncPullFailed`, `syncPullSignedOut`
(de: "Synchronisieren hat nicht geklappt. Es wird gleich erneut
versucht." / "Deine Sitzung ist abgelaufen. Melde dich in den
Einstellungen erneut an."; it: "La sincronizzazione non è riuscita.
Riproverà a breve." / "La sessione è scaduta. Accedi di nuovo nelle
Impostazioni.").

## Testing

Widget tests with `syncEngineProvider` overridden by a fake notifier
(subclass of `SyncEngine` with `build` returning a chosen state and
`syncNow` recording calls and moving through `syncing` to a chosen end
status):

- no account: no `sync-refresh`, a fling down does not call `syncNow`;
- signed in: fling down on Today calls `syncNow` once; the indicator is
  shown until the fake completes;
- already running: the pull waits until the status leaves `syncing`;
- offline / error / signedOut end states each show their snackbar; idle
  shows none;
- an empty Today and an empty Notes can be pulled;
- each listed screen contains `sync-refresh` when signed in.
