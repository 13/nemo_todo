import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/format.dart';

/// Account and synchronisation tiles inside Settings.
class SyncSettingsSection extends ConsumerWidget {
  const SyncSettingsSection({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    // Where an account is required, signing out empties the device as
    // well, so the confirmation says so rather than promising otherwise.
    final wipes = ref.read(authRequiredProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsSignOut),
        content: Text(
          wipes ? l.settingsSignOutConfirmWeb : l.settingsSignOutConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.settingsSignOut),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(syncEngineProvider.notifier).onSignedOut();
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final sync = ref.watch(syncEngineProvider);
    final locale = Localizations.localeOf(context).toString();

    if (!auth.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l.settingsAccount),
          ListTile(
            key: const Key('connect-tile'),
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(l.settingsConnect),
            subtitle: Text(
              auth.serverUrl != null
                  ? l.settingsSignedOutRemotely
                  : l.settingsNotConnected,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.account),
          ),
        ],
      );
    }

    final (statusText, statusColor) = switch (sync.status) {
      SyncStatus.syncing => (l.settingsSyncing, scheme.onSurfaceVariant),
      SyncStatus.offline => (l.settingsOffline, scheme.onSurfaceVariant),
      SyncStatus.error => (l.settingsSyncError(sync.error ?? ''), scheme.error),
      SyncStatus.signedOut => (l.settingsSignedOutRemotely, scheme.error),
      _ => (l.settingsPending(sync.pending), scheme.onSurfaceVariant),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.settingsAccount),
        ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(l.settingsConnectedAs(auth.username!, auth.serverUrl!)),
          subtitle: Text(
            sync.lastSyncAt == null
                ? l.settingsNeverSynced
                : l.settingsLastSync(
                    timeLabel(locale, sync.lastSyncAt!.millisecondsSinceEpoch),
                  ),
          ),
        ),
        SectionHeader(title: l.settingsSync),
        ListTile(
          key: const Key('sync-now'),
          leading: sync.status == SyncStatus.syncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          title: Text(l.settingsSyncNow),
          subtitle: Text(statusText, style: TextStyle(color: statusColor)),
          onTap: sync.status == SyncStatus.syncing
              ? null
              : () => ref.read(syncEngineProvider.notifier).syncNow(),
        ),
        if (sync.discarded > 0)
          ListTile(
            key: const Key('sync-discarded'),
            leading: Icon(Icons.warning_amber_rounded, color: scheme.error),
            title: Text(l.settingsDiscarded(sync.discarded)),
            trailing: TextButton(
              onPressed: () =>
                  ref.read(syncEngineProvider.notifier).clearDiscarded(),
              child: Text(l.commonOk),
            ),
          ),
        ListTile(
          key: const Key('sign-out'),
          leading: Icon(Icons.logout_rounded, color: scheme.error),
          title: Text(l.settingsSignOut, style: TextStyle(color: scheme.error)),
          onTap: () => _signOut(context, ref),
        ),
      ],
    );
  }
}
