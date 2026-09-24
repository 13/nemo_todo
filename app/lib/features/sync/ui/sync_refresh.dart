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
  const SyncRefresh.scrollable({required this.child, super.key}) : _fill = true;

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
      onRefresh: () => _refresh(context),
      child: content,
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    String? message;
    try {
      await container.read(syncEngineProvider.notifier).syncNow();
      var status = container.read(syncEngineProvider).status;
      if (status == SyncStatus.syncing) {
        final done = Completer<SyncStatus>();
        final sub = container.listen<SyncStatus>(
          syncEngineProvider.select((s) => s.status),
          (_, next) {
            // A 401 passes through `local` (no account) on its way to
            // `signedOut`, so `local` does not end the wait either, or
            // the signed-out snackbar is lost.
            if (next != SyncStatus.syncing &&
                next != SyncStatus.local &&
                !done.isCompleted) {
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
      message = switch (status) {
        SyncStatus.offline => l.settingsOffline,
        SyncStatus.error => l.syncPullFailed,
        SyncStatus.signedOut => l.syncPullSignedOut,
        _ => null,
      };
    } on Object catch (e, st) {
      // An unexpected error must never escape `onRefresh` -- that would
      // surface as an uncaught exception instead of a snackbar.
      debugPrint('SyncRefresh: unexpected error during pull to sync: $e\n$st');
      message = l.syncPullFailed;
    }
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
