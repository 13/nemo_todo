import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/sync/data/sse_client.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_engine.g.dart';

/// Builds the client that talks to the server. Replaced in tests.
typedef SyncClientFactory = SyncClient Function(String baseUrl, String token);

/// Builds the live-update stream, or null where there should not be one.
typedef SseClientFactory = SseClient? Function(
  String baseUrl,
  String token,
  void Function() onChanged,
);

final syncClientFactoryProvider = Provider<SyncClientFactory>(
  (ref) =>
      (baseUrl, token) =>
          SyncClient(ref.read(dioProvider), baseUrl: baseUrl, token: token),
);

/// How long a failed sync waits before trying itself again, and the ceiling
/// that wait doubles up to.
typedef RetryPolicy = ({Duration initial, Duration max});

/// A failure used to wait for something else to happen -- a local edit, the
/// app coming back to the foreground, the event stream reconnecting. On a
/// device nobody is touching, and against a server that is answering with
/// errors rather than refusing the connection, none of those arrive, and
/// the queue sat there. So a failed sync now schedules its own next try.
final syncRetryPolicyProvider = Provider<RetryPolicy>(
  (ref) =>
      (initial: const Duration(seconds: 5), max: const Duration(minutes: 5)),
);

final sseClientFactoryProvider = Provider<SseClientFactory>(
  (ref) =>
      (baseUrl, token, onChanged) => SseClient(
        ref.read(dioProvider),
        baseUrl: baseUrl,
        token: token,
        onChanged: onChanged,
      ),
);

/// Drives synchronisation with the server.
///
/// One run at a time: a request arriving mid-run sets a flag and the loop
/// goes round again, so a burst of edits costs one round trip. Everything
/// the server sends is applied with the same last-write-wins rule the
/// server used, so both sides converge.
@Riverpod(keepAlive: true)
class SyncEngine extends _$SyncEngine {
  Timer? _debounce;
  SseClient? _sse;
  var _running = false;
  var _again = false;
  Duration? _retryIn;

  @override
  SyncState build() {
    final auth = ref.watch(authControllerProvider);
    ref.onDispose(() {
      _debounce?.cancel();
      _sse?.stop();
    });
    // Any local change schedules a push shortly afterwards. Not fired
    // immediately: the notifier has no state to update until build returns.
    ref.listen(pendingChangesProvider, (_, next) {
      final count = next.value ?? 0;
      state = state.copyWith(pending: count);
      if (count > 0) requestSync();
    });

    if (!auth.connected) {
      _sse?.stop();
      _sse = null;
      return const SyncState();
    }
    _startEvents(auth);
    return SyncState(
      status: SyncStatus.idle,
      lastSyncAt: _storedLastSync(),
      pending: ref.read(pendingChangesProvider).value ?? 0,
    );
  }

  DateTime? _storedLastSync() {
    final raw = ref.read(bootstrapProvider).lastSyncAt;
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  void _startEvents(AuthState auth) {
    _sse?.stop();
    _sse = ref.read(sseClientFactoryProvider)(
      auth.serverUrl!,
      auth.token!,
      requestSync,
    )?..start();
  }

  SyncClient? _client() {
    final auth = ref.read(authControllerProvider);
    if (!auth.connected) return null;
    return ref.read(syncClientFactoryProvider)(auth.serverUrl!, auth.token!);
  }

  /// Asks for a sync soon, coalescing bursts of edits.
  void requestSync({Duration delay = const Duration(seconds: 2)}) {
    if (!ref.read(authControllerProvider).connected) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  /// Asks for another try after a failure, waiting longer each time.
  ///
  /// It goes through [requestSync], so anything that asks for a sync sooner
  /// -- an edit, a resume, the event stream reconnecting -- replaces the
  /// wait rather than queueing behind it.
  void _scheduleRetry() {
    final policy = ref.read(syncRetryPolicyProvider);
    final delay = _retryIn ?? policy.initial;
    requestSync(delay: delay);
    final next = delay * 2;
    _retryIn = next > policy.max ? policy.max : next;
  }

  /// Uploads queued changes and applies everything new from the server.
  Future<void> syncNow() async {
    if (_running) {
      _again = true;
      return;
    }
    final client = _client();
    if (client == null) return;
    _running = true;
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      do {
        _again = false;
        await _runOnce(client);
      } while (_again);
      _retryIn = null;
      state = state.copyWith(status: SyncStatus.idle);
    } on ApiError catch (e) {
      if (e.isUnauthorized) {
        // Nothing to retry: the session is gone until someone signs in.
        _retryIn = null;
        await ref.read(authControllerProvider.notifier).sessionExpired();
        state = state.copyWith(status: SyncStatus.signedOut);
      } else {
        state = state.copyWith(
          status: e.isOffline ? SyncStatus.offline : SyncStatus.error,
          error: e.code,
        );
        _scheduleRetry();
      }
    } finally {
      _running = false;
      state = state.copyWith(
        pending: await ref.read(appDatabaseProvider).outboxCount(),
      );
    }
  }

  Future<void> _runOnce(SyncClient client) async {
    final db = ref.read(appDatabaseProvider);
    final kv = ref.read(kvStoreProvider);
    final clock = ref.read(hlcClockProvider);
    final reminders = ref.read(reminderSchedulerProvider);
    var hasMore = true;
    var pushed = false;
    while (hasMore) {
      final cursor = int.tryParse(await kv.get(KvKeys.cursor) ?? '0') ?? 0;
      // Only the first request of a round carries the queue; later pages
      // are pure pulls.
      final changes = pushed ? <SyncChange>[] : await db.outboxChanges();
      final response = await client.sync(
        SyncRequest(cursor: cursor, changes: changes),
      );
      pushed = true;
      await db.ackOutbox(changes);
      for (final rejected in response.rejected) {
        await db.dropOutbox(rejected.entity, rejected.rowId);
      }
      if (response.rejected.isNotEmpty) {
        state = state.copyWith(
          discarded: state.discarded + response.rejected.length,
        );
      }
      for (final change in response.changes) {
        final task = await db.applyRemote(change);
        if (task != null) await reminders.sync(task);
      }
      await db.setListMeta(
        response.members,
        ref.read(authControllerProvider).username ?? '',
      );
      clock.receive(Hlc.parse(response.serverHlc));
      await kv.set(KvKeys.hlcLast, clock.last.toString());
      await kv.set(KvKeys.cursor, '${response.cursor}');
      hasMore = response.hasMore;
    }
    final now = ref.read(nowProvider)();
    await kv.set(KvKeys.lastSyncAt, '${now.millisecondsSinceEpoch}');
    state = state.copyWith(lastSyncAt: now);
  }

  /// After connecting an account, every local row is offered to the server.
  Future<void> onSignedIn() async {
    await ref.read(appDatabaseProvider).enqueueAll();
    await syncNow();
  }

  Future<void> onSignedOut() async {
    _debounce?.cancel();
    _sse?.stop();
    _sse = null;
    final db = ref.read(appDatabaseProvider);
    await db.clearListMeta();
    if (ref.read(authRequiredProvider)) {
      // Nothing here is this device's to keep: the next person to sign in
      // on it gets their own tasks from the server rather than inheriting
      // -- and uploading -- the last one's.
      await db.clearLocalData();
      await ref.read(listsRepositoryProvider).ensureInbox();
    }
    state = const SyncState();
  }

  /// The user has seen the "changes were rejected" notice.
  void clearDiscarded() => state = state.copyWith(discarded: 0);
}

/// Number of local changes waiting to reach the server.
@Riverpod(keepAlive: true)
Stream<int> pendingChanges(Ref ref) =>
    ref.watch(appDatabaseProvider).watchOutboxCount();

/// Syncs when the app comes back to the foreground.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(syncEngineProvider.notifier)
          .requestSync(delay: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
