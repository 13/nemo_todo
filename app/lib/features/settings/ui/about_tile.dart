import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// What this app is, and what it is talking to.
///
/// Two builds are involved and either can be stale: the server, and the
/// page a browser may have been holding in cache since before the server
/// moved. Naming only one of them leaves the other to be worked out from
/// the outside, by hashing whatever the server is serving against the
/// releases -- which is what it took the last time they disagreed.
class AboutTile extends ConsumerWidget {
  const AboutTile({super.key});

  /// True when the server is running something newer than this build, and
  /// both said so in a form that can be compared. A version that will not
  /// parse is shown rather than judged.
  static bool appIsBehind(AppVersion? app, String? server) {
    if (app == null || server == null || server.isEmpty) return false;
    final theirs = AppVersion.tryParse(server);
    return theirs != null && theirs.isNewerThan(app);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final app = ref.watch(currentVersionProvider).value;
    final sync = ref.watch(syncEngineProvider);

    // No account means no server to name. An empty string means a server
    // too old to say, which is not a mismatch either.
    final server = sync.connected ? sync.serverVersion : null;
    final appLabel = app?.toString() ?? '—';
    final named = server != null && server.isNotEmpty;

    // Only where a reload is the fix. On Android, being behind the server
    // is ordinary and the update tile above already offers the download.
    final stale = ref.watch(servedByServerProvider) && appIsBehind(app, server);

    return ListTile(
      key: const Key('about-tile'),
      leading: Icon(
        stale ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
        color: stale ? theme.colorScheme.error : null,
      ),
      title: Text(l.appName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Read from the package rather than written here, so it cannot
          // go on claiming 0.1.0 after a release.
          Text(
            named
                ? l.settingsVersions(appLabel, server)
                : l.settingsVersion(appLabel),
          ),
          if (stale)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.settingsServerNewer,
                key: const Key('about-stale'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
