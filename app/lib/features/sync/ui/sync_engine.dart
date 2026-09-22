import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/sync/data/blob_transfer.dart';
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

  /// Whether a picture failed to move this run in a way that trying again
  /// could fix. The tasks may still have synced, so this does not make the
  /// sync an error; it only asks for another run with the usual backoff.
  var _blobRetry = false;

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
      serverVersion: ref.read(bootstrapProvider).serverVersion,
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
    _blobRetry = false;
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      do {
        _again = false;
        await _runOnce(client);
      } while (_again);
      if (_blobRetry) {
        _scheduleRetry();
      } else {
        _retryIn = null;
      }
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
    var listsArrived = false;
    // A server that has said it has no photos answers an upload with a 404
    // only after the whole body has been sent -- so the bytes are not
    // offered at all until it says otherwise.
    final uploadsHeld = await kv.get(KvKeys.serverPhotos) == 'false';
    if (!uploadsHeld) await _uploadPending(client);
    while (hasMore) {
      final cursor = int.tryParse(await kv.get(KvKeys.cursor) ?? '0') ?? 0;
      // A server from before photos, or before notes, refuses the whole
      // request over a change it cannot decode, everything else in the
      // push along with it, and every later request carries the same
      // queue. So each kind of change waits until the server has said it
      // takes it.
      final serverPhotos = await kv.get(KvKeys.serverPhotos) == 'true';
      final serverNotes = await kv.get(KvKeys.serverNotes) == 'true';
      // Only the first request of a round carries the queue; later pages
      // are pure pulls.
      final changes = pushed
          ? <SyncChange>[]
          : await db.outboxChanges(
              includePhotos: serverPhotos,
              includeNotes: serverNotes,
            );
      final SyncResponse response;
      try {
        response = await client.sync(
          SyncRequest(
            cursor: cursor,
            changes: changes,
            photos: true,
            notes: true,
          ),
        );
      } on ApiError catch (e) {
        // What a server rolled back to a release without photos, or
        // without notes, answers a change of that kind with. Left saying
        // true, the next request would carry the same change and be
        // refused the same way, forever; this way the retry goes without
        // it, and the answer to it says again whether the server takes it.
        // The response never says which of the two changes it choked on,
        // so both are held back until the next answer sorts them out.
        if (e.status == 400 && e.code == 'bad_request') {
          await kv.set(KvKeys.serverPhotos, 'false');
          await kv.set(KvKeys.serverNotes, 'false');
        }
        rethrow;
      }
      await kv.set(KvKeys.serverPhotos, '${response.photos}');
      await kv.set(KvKeys.serverNotes, '${response.notes}');
      // Only checked on the first page of a round: later pages are pure
      // pulls, with nothing queued to have been held back from them.
      if (!pushed) {
        // The server has just said it takes photos, and this request did
        // not carry the ones waiting for that: go round again now rather
        // than at the next edit. Only for photos that would actually be
        // sent -- a row still waiting on its upload would send the loop
        // round for nothing -- unless the upload itself was what this
        // round held back, in which case the bytes are what round two
        // would send.
        final photoRoundNeeded =
            response.photos &&
            ((uploadsHeld && (await db.pendingBlobs()).isNotEmpty) ||
                (!serverPhotos &&
                    (await db.outboxChanges(
                      includePhotos: true,
                      includeNotes: true,
                    )).any((c) => c.entity == SyncEntity.photo)));
        // Same idea for notes: the server has just said it takes them, and
        // this request's queue was built before that was known, so a note
        // -- or a picture hanging on one, with no note beside it in the
        // queue -- held back is worth sending now rather than waiting for
        // the next edit.
        final noteRoundNeeded =
            response.notes &&
            !serverNotes &&
            (await db.outboxChanges(
              includePhotos: true,
              includeNotes: true,
            )).any(
              (c) =>
                  c.entity == SyncEntity.note ||
                  (c is SyncChangePhoto &&
                      c.row.parentKind == PhotoParent.note),
            );
        if (photoRoundNeeded || noteRoundNeeded) _again = true;
      }
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
        if (change is SyncChangeList) listsArrived = true;
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
      // Kept so Settings can name the server before the first sync of the
      // next session, and while offline. A server too old to say sends an
      // empty string, which is stored as such: it means "did not say", not
      // "no server".
      await kv.set(KvKeys.serverVersion, response.serverVersion);
      state = state.copyWith(serverVersion: response.serverVersion);
      hasMore = response.hasMore;
    }
    if (ref.read(photoDownloadEagerProvider)) await _downloadMissing(client);
    // A device that was used offline before it had an account brings its
    // own Inbox to one that already has one, and the first sync lands
    // both. Settled here rather than at the next launch, so nobody is
    // left looking at two Inboxes until they restart the app.
    if (listsArrived) {
      await ref.read(listsRepositoryProvider).mergeDuplicateInboxes();
    }
    final now = ref.read(nowProvider)();
    await kv.set(KvKeys.lastSyncAt, '${now.millisecondsSinceEpoch}');
    state = state.copyWith(lastSyncAt: now);
    // Whatever this device holds as `synced` -- uploaded or downloaded --
    // is now known to be this account's. Recorded after every sync, not
    // only at sign-in or when an upload lands: a device that was signed in
    // before it was upgraded, and only ever downloads, would otherwise
    // record nothing, and a later switch of account would not know to
    // upload its pictures again.
    final account = _account();
    if (account != null) await kv.set(KvKeys.blobAccount, account);
  }

  BlobTransfer _blobs() =>
      BlobTransfer(ref.read(appDatabaseProvider), ref.read(photoStoreProvider));

  /// Sends the bytes of every picture the server does not have yet, and
  /// records what the server said about them.
  Future<void> _uploadPending(SyncClient client) async {
    final outcome = await _blobs().uploadPending(client);
    if (outcome.retry) _blobRetry = true;
    // A refusal that will not change on its own -- too large, or no room
    // on the server -- is kept until an upload gets through, rather than
    // cleared at the start of every sync only to be found again, or the
    // photo sits there marked "not uploaded" with no reason given.
    if (outcome.refusal != null) {
      state = state.copyWith(photoError: outcome.refusal!.code);
    } else if (outcome.landed) {
      state = state.copyWith(clearPhotoError: true);
    }
    // Not left to the end of the sync alone: the push after this can fail,
    // and these bytes are this account's all the same.
    final account = _account();
    if (outcome.landed && account != null) {
      await ref.read(kvStoreProvider).set(KvKeys.blobAccount, account);
    }
  }

  /// Which server and account this device is talking to, as far as picture
  /// bytes are concerned: a username only means something on its server.
  String? _account() {
    final auth = ref.read(authControllerProvider);
    if (!auth.connected) return null;
    return '${auth.serverUrl}|${auth.username}';
  }

  Future<void> _downloadMissing(SyncClient client) async {
    if (await _blobs().downloadMissing(client)) _blobRetry = true;
  }

  /// After connecting an account, every local row is offered to the server.
  Future<void> onSignedIn() async {
    final db = ref.read(appDatabaseProvider);
    final account = _account();
    if (account != null) {
      final kv = ref.read(kvStoreProvider);
      final previous = await kv.get(KvKeys.blobAccount);
      // Android keeps its data across a sign-out, so the rows about to be
      // offered may go to a different account or server than the one whose
      // `synced` their bytes are. That server has none of them: upload them
      // all again, or it gets rows it can never serve a picture for. A
      // first sign-in has nothing recorded, and nothing to redo.
      if (previous != null && previous != account) {
        await _blobs().repend();
      }
      await kv.set(KvKeys.blobAccount, account);
      // What the last server said about photos, or notes, says nothing
      // about this one. Unsaid, the first request holds those changes back
      // and its answer settles it, instead of an older server refusing
      // the lot.
      await kv.set(KvKeys.serverPhotos, null);
      await kv.set(KvKeys.serverNotes, null);
    }
    await db.enqueueAll();
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
