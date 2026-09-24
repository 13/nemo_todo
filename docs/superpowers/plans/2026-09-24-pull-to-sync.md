# Pull to Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pulling down on the main list screens runs a sync when an account is connected.

**Architecture:** One `SyncRefresh` widget (Material `RefreshIndicator`) calls `SyncEngine.syncNow()`, waits until the status leaves `syncing`, and reports offline / error / signed-out in a snackbar. Screens wrap their main vertical scrollable (and their empty state) in it. Spec: `docs/superpowers/specs/2026-09-24-pull-to-sync-design.md`.

**Tech Stack:** Flutter 3.47 (fvm), Riverpod (generated `syncEngineProvider`), flutter_test with `pumpApp`.

## Global Constraints

- UI only: no change to `SyncEngine`'s behaviour, the server or the protocol.
- With `SyncStatus.local` (no account) the gesture is off: no `RefreshIndicator`, `syncNow` never called.
- The spinner stays until the sync has finished; a pull during a running sync waits for it (60 s safety timeout).
- Snackbars: `offline` -> existing `settingsOffline`; `error` -> new `syncPullFailed`; `signedOut` -> new `syncPullSignedOut`; `idle` -> none.
- Screens: Today, Upcoming, list detail, tag (all via `TaskListView` + their empty states), Lists, Notes, Search results.
- Key of the indicator: `sync-refresh`.
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, from `app/`; `flutter test --concurrency=2` on a directory or single file, one process at a time, 600 s timeout.
- Commit messages end with the attribution lines in the session's system reminder.
- Branch `feat/pull-to-sync` (checked out, spec committed).

---

### Task 1: `SyncRefresh` widget and strings

**Files:**
- Create: `app/lib/features/sync/ui/sync_refresh.dart`
- Modify: `app/lib/l10n/app_{en,de,it}.arb` (+ `flutter gen-l10n`)
- Test: `app/test/features/sync/sync_refresh_test.dart`

**Interfaces:**
- Produces: `SyncRefresh({required Widget child})` (child: a vertical scrollable); `SyncRefresh.scrollable({required Widget child})` -- for a non-scrolling child such as `EmptyState`: makes it pullable by putting it in an always-scrollable, full-height scroll view; l10n `syncPullFailed`, `syncPullSignedOut`.

- [ ] **Step 1: Strings**

`app_en.arb` (with `@` descriptions "Snackbar after pulling down to sync when ..."):
- `syncPullFailed`: "Sync didn't work. It will try again shortly."
- `syncPullSignedOut`: "Your session has ended. Sign in again in Settings."

de: "Synchronisieren hat nicht geklappt. Es wird gleich erneut versucht." / "Deine Sitzung ist abgelaufen. Melde dich in den Einstellungen erneut an."
it: "La sincronizzazione non è riuscita. Riproverà a breve." / "La sessione è scaduta. Accedi di nuovo nelle Impostazioni."

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/features/sync/sync_refresh_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_refresh.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// A sync engine that starts in [initial] and, on [syncNow], goes through
/// `syncing` to [end] once [gate] completes.
class _FakeSyncEngine extends SyncEngine {
  _FakeSyncEngine(this.initial, {required this.end, Completer<void>? gate})
    : gate = gate ?? (Completer<void>()..complete());

  final SyncStatus initial;
  final SyncStatus end;
  final Completer<void> gate;
  int calls = 0;

  @override
  SyncState build() => SyncState(status: initial);

  @override
  Future<void> syncNow() async {
    calls++;
    state = SyncState(status: SyncStatus.syncing);
    await gate.future;
    state = SyncState(status: end);
  }

  /// Finishes a run someone else started, as the real engine would.
  void finish() => state = SyncState(status: end);
}

Future<_FakeSyncEngine> _pump(
  WidgetTester tester,
  _FakeSyncEngine engine, {
  bool empty = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncEngineProvider.overrideWith(() => engine)],
      child: MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: empty
              ? const SyncRefresh.scrollable(child: Center(child: Text('empty')))
              : SyncRefresh(
                  child: ListView(
                    children: const [ListTile(title: Text('row'))],
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pump();
  return engine;
}

Future<void> _pull(WidgetTester tester, String text) async {
  await tester.fling(find.text(text), const Offset(0, 400), 1000);
  await tester.pump(); // start the refresh
  await tester.pump(const Duration(seconds: 1)); // indicator settles
}

void main() {
  testWidgets('no account: no indicator and no sync', (tester) async {
    final engine = await _pump(
      tester,
      _FakeSyncEngine(SyncStatus.local, end: SyncStatus.idle),
    );
    expect(find.byKey(const Key('sync-refresh')), findsNothing);
    await _pull(tester, 'row');
    expect(engine.calls, 0);
  });

  testWidgets('a pull syncs and the spinner waits for it', (tester) async {
    final gate = Completer<void>();
    final engine = await _pump(
      tester,
      _FakeSyncEngine(SyncStatus.idle, end: SyncStatus.idle, gate: gate),
    );
    await _pull(tester, 'row');
    expect(engine.calls, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a pull during a running sync waits for that one', (tester) async {
    final engine = _BusyEngine();
    await _pumpBusy(tester, engine);
    await _pull(tester, 'row');
    expect(engine.calls, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    engine.finish();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  for (final (end, text) in [
    (SyncStatus.offline, 'Offline. Changes will sync when you are back online.'),
    (SyncStatus.error, "Sync didn't work. It will try again shortly."),
    (SyncStatus.signedOut, 'Your session has ended. Sign in again in Settings.'),
  ]) {
    testWidgets('ending $end says so', (tester) async {
      await _pump(tester, _FakeSyncEngine(SyncStatus.idle, end: end));
      await _pull(tester, 'row');
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('an empty screen can be pulled', (tester) async {
    final engine = await _pump(
      tester,
      _FakeSyncEngine(SyncStatus.idle, end: SyncStatus.idle),
      empty: true,
    );
    await _pull(tester, 'empty');
    expect(engine.calls, 1);
  });
}
```

Add to the test file, next to `_FakeSyncEngine`:

```dart
/// A run is already going: `syncNow` only marks "go again" and returns at
/// once, as the real engine does.
class _BusyEngine extends SyncEngine {
  int calls = 0;

  @override
  SyncState build() => const SyncState(status: SyncStatus.syncing);

  @override
  Future<void> syncNow() async => calls++;

  void finish() => state = const SyncState(status: SyncStatus.idle);
}
```

and a `_pumpBusy(tester, _BusyEngine engine)` identical to `_pump` but overriding with `engine` (or make `_pump` generic over `SyncEngine`).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/sync/sync_refresh_test.dart` -- `sync_refresh.dart` not found.

- [ ] **Step 4: Implement**

```dart
// app/lib/features/sync/ui/sync_refresh.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Pull down to sync, on a screen of synced data.
///
/// Off without an account: nothing is there to sync, and a spinner would
/// pretend otherwise. The spinner lasts until the sync has really finished
/// -- `syncNow` returns at once when a run is already going -- and a
/// failure is said in a snackbar; a success needs no words.
class SyncRefresh extends ConsumerWidget {
  const SyncRefresh({required this.child, super.key}) : _fill = false;

  /// For a child that does not scroll itself, such as an empty state: it is
  /// laid out at full height inside a scroll view that can always be
  /// pulled.
  const SyncRefresh.scrollable({required this.child, super.key})
    : _fill = true;

  final Widget child;
  final bool _fill;

  static const _timeout = Duration(seconds: 60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncEngineProvider.select((s) => s.status));
    final content = _fill
        ? LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: child,
              ),
            ),
          )
        : child;
    if (status == SyncStatus.local) return content;
    return RefreshIndicator(
      key: const Key('sync-refresh'),
      onRefresh: () => _refresh(context, ref),
      child: content,
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    await container.read(syncEngineProvider.notifier).syncNow();
    var status = container.read(syncEngineProvider).status;
    if (status == SyncStatus.syncing) {
      final done = Completer<SyncStatus>();
      final sub = container.listen<SyncStatus>(
        syncEngineProvider.select((s) => s.status),
        (_, next) {
          if (next != SyncStatus.syncing && !done.isCompleted) {
            done.complete(next);
          }
        },
      );
      try {
        status = await done.future.timeout(_timeout, onTimeout: () => status);
      } finally {
        sub.close();
      }
    }
    final message = switch (status) {
      SyncStatus.offline => l.settingsOffline,
      SyncStatus.error => l.syncPullFailed,
      SyncStatus.signedOut => l.syncPullSignedOut,
      _ => null,
    };
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
```

Note: the plain `SyncRefresh` requires its child to be scrollable with always-scrollable physics for short lists; Task 2 sets that on each screen. The `ListView` in the test has default physics; if a one-row list cannot be pulled there, give the test's `ListView` `physics: const AlwaysScrollableScrollPhysics()` (it mirrors what screens do) rather than changing the widget.

- [ ] **Step 5: Run to verify pass**

`flutter test test/features/sync/sync_refresh_test.dart` -- pass. Format and analyze clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sync/ui/sync_refresh.dart app/lib/l10n app/test/features/sync/sync_refresh_test.dart
git commit -m "feat(app): pull down to sync"
```

---

### Task 2: Wire the screens

**Files:**
- Modify: `app/lib/features/tasks/ui/task_list_view.dart` (`TaskListView.build`)
- Modify: `app/lib/features/tasks/ui/today_screen.dart`, `upcoming_screen.dart`, `tag_screen.dart`, `search_screen.dart`
- Modify: `app/lib/features/lists/ui/list_detail_screen.dart`, `lists_screen.dart`
- Modify: `app/lib/features/notes/ui/notes_screen.dart`
- Test: `app/test/features/sync/pull_to_sync_screens_test.dart`

**Interfaces:**
- Consumes: `SyncRefresh`, `SyncRefresh.scrollable` (Task 1).

Changes:
- `TaskListView.build`: `SyncRefresh(child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [...]))`. This covers Today, Upcoming, list detail and tag when they have tasks.
- Empty states on Today, Upcoming, list detail, tag, Notes: `SyncRefresh.scrollable(child: EmptyState(...))`.
- Lists screen: wrap its `CustomScrollView` (add always-scrollable physics). If it has a separate empty state, wrap it with `.scrollable`.
- Notes: wrap the grid's `CustomScrollView` (always-scrollable physics); the `LayoutBuilder` stays outside or inside as fits.
- Search: wrap the results `CustomScrollView` and the "no results" empty state; leave the "type to search" state (no query) unwrapped.
- If a screen's `CustomScrollView` already sets `physics`, combine: `AlwaysScrollableScrollPhysics(parent: <existing>)`.

- [ ] **Step 1: Write the failing tests**

`pull_to_sync_screens_test.dart` using `pumpApp` with `overrides: [syncEngineProvider.overrideWith(() => _SignedInEngine())]` where `_SignedInEngine extends SyncEngine` builds `SyncState(status: SyncStatus.idle)` and records `syncNow` calls (returns at once, state unchanged):

- for each of `Routes.today`, `Routes.upcoming`, `Routes.lists`, `Routes.list('l1')`, `Routes.notes`, `Routes.tag('x')`, and search with a query that has results: after seeding one matching item, `find.byKey(const Key('sync-refresh'))` finds one; a fling down on the screen's first row calls `syncNow` once.
- Today with nothing due and Notes with no notes (empty states): a fling down on the empty-state text calls `syncNow`.
- Default `pumpApp` without the override (no account): Today has no `sync-refresh`.

Use the seed helpers in `test/support/pump_app.dart` (`seedList`, `seedTask`, `seedNote`); for search, check how existing search tests enter a query.

- [ ] **Step 2: Run to verify failure**

`flutter test test/features/sync/pull_to_sync_screens_test.dart` -- fails (no `sync-refresh` on the screens).

- [ ] **Step 3: Implement** the changes above.

- [ ] **Step 4: Run to verify pass**

`flutter test test/features/sync`, then `test/features/tasks`, `test/features/lists`, `test/features/notes` -- all pass (existing scroll/drag tests included: a reorderable list or swipe-to-complete must still work; if a drag test breaks because the list is now always scrollable, investigate before changing the test). Format and analyze clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features app/test/features/sync/pull_to_sync_screens_test.dart
git commit -m "feat(app): pull down on the task, list and note screens to sync"
```

---

### Task 3: Changelog and verification

- [ ] **Step 1:** In `CHANGELOG.md`, add under the intro, above `## 0.13.0 - 2026-09-24`:

```markdown
## Unreleased

### Added

- Pull down on Today, Upcoming, Lists, a list, a tag, Notes or search
  results to sync straight away when an account is connected. If the
  server cannot be reached, a short message says your changes are saved
  and will sync later.
```

- [ ] **Step 2:** One at a time: `dart format --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --concurrency=2 test/features/sync`, `flutter test --concurrency=2 --exclude-tags design`. All clean / passing.

- [ ] **Step 3:** `git add CHANGELOG.md && git commit -m "docs: pull to sync in the changelog"`
