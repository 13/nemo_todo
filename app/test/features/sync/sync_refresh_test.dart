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
    state = const SyncState(status: SyncStatus.syncing);
    await gate.future;
    state = SyncState(status: end);
  }

  /// Finishes a run someone else started, as the real engine would.
  void finish() => state = SyncState(status: end);
}

/// A run is already going: `syncNow` only marks "go again" and returns at
/// once, as the real engine does.
class _BusyEngine extends SyncEngine {
  int calls = 0;

  @override
  SyncState build() => const SyncState(status: SyncStatus.syncing);

  @override
  Future<void> syncNow() async => calls++;

  void finish() => state = const SyncState(status: SyncStatus.idle);

  /// Sets an intermediate status without ending the wait, as the real
  /// engine does moving through `local` on the way to `signedOut`.
  void step(SyncStatus status) => state = SyncState(status: status);
}

/// A `syncNow` that always throws, as an unexpected error would.
class _ThrowingEngine extends SyncEngine {
  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);

  @override
  Future<void> syncNow() async => throw StateError('boom');
}

Future<T> _pump<T extends SyncEngine>(
  WidgetTester tester,
  T engine, {
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
              ? const SyncRefresh.scrollable(
                  child: Center(child: Text('empty')),
                )
              : SyncRefresh(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
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

Future<_BusyEngine> _pumpBusy(WidgetTester tester, _BusyEngine engine) =>
    _pump(tester, engine);

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

  testWidgets('a pull during a running sync waits for that one', (
    tester,
  ) async {
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
    (
      SyncStatus.offline,
      'Offline. Changes will sync when you are back online.',
    ),
    (SyncStatus.error, "Sync didn't work. It will try again shortly."),
    (
      SyncStatus.signedOut,
      'Your session has ended. Sign in again in Settings.',
    ),
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

  testWidgets('a busy sync passing through local still waits for signed-out', (
    tester,
  ) async {
    final engine = _BusyEngine();
    await _pumpBusy(tester, engine);
    await _pull(tester, 'row');
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    // `local` unmounts the RefreshIndicator (no account -> no gesture), but
    // the wait behind it must keep going rather than settle for `local`.
    engine.step(SyncStatus.local);
    await tester.pump();
    engine.step(SyncStatus.signedOut);
    await tester.pumpAndSettle();
    expect(
      find.text('Your session has ended. Sign in again in Settings.'),
      findsOneWidget,
    );
  });

  testWidgets('an unexpected error from syncNow is reported, not thrown', (
    tester,
  ) async {
    await _pump(tester, _ThrowingEngine());
    await _pull(tester, 'row');
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(
      find.text("Sync didn't work. It will try again shortly."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a busy sync that never finishes times out with no snackbar', (
    tester,
  ) async {
    final engine = _BusyEngine();
    await _pumpBusy(tester, engine);
    await _pull(tester, 'row');
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
