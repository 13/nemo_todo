import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nemo/core/build_info.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/settings/data/server_build.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app. Replaced in tests.
final openUrlProvider = Provider<Future<bool> Function(Uri)>(
  (_) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// What this app is, and what it is talking to.
///
/// Two builds are involved and either can be stale: the server, and the
/// page a browser may have been holding in cache since before the server
/// moved. Naming only one of them leaves the other to be worked out from
/// the outside, by hashing whatever the server is serving against the
/// releases -- which is what it took the last time they disagreed.
class AboutTile extends ConsumerWidget {
  const AboutTile({super.key});

  static final Uri sourceUrl = Uri.parse('https://github.com/13/nemo_todo');

  /// True when the server is running something newer than this build, and
  /// both said so in a form that can be compared. A version that will not
  /// parse is shown rather than judged.
  static bool appIsBehind(AppVersion? app, String? server) {
    if (app == null || server == null || server.isEmpty) return false;
    final theirs = AppVersion.tryParse(server);
    return theirs != null && theirs.isNewerThan(app);
  }

  /// The plain-text summary "Copy details" puts on the clipboard, for a bug
  /// report. English and unformatted on purpose: it is read by whoever
  /// fixes the bug, not by the person filing it. The server's address stays
  /// out, since reports tend to be pasted somewhere public.
  static String details({
    required AppVersion? app,
    required String buildNumber,
    required BuildInfo build,
    required String platform,
    String? serverVersion,
    ServerBuild? server,
  }) => [
    'nemo ${app ?? '?'}${buildNumber.isEmpty ? '' : ' (build $buildNumber)'}',
    'channel: ${build.channel}',
    'commit: ${build.commit.isEmpty ? '-' : build.commit}',
    'built: ${build.builtAt?.toIso8601String() ?? '-'}',
    'platform: $platform',
    if (serverVersion != null)
      'server: ${serverVersion.isEmpty ? '?' : serverVersion}',
    if (server?.commit != null) 'server commit: ${server!.commit}',
    if (server?.builtAt != null)
      'server built: ${server!.builtAt!.toIso8601String()}',
  ].join('\n');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final app = ref.watch(currentVersionProvider).value;
    final number = ref.watch(buildNumberProvider).value ?? '';
    final build = ref.watch(buildInfoProvider);
    final sync = ref.watch(syncEngineProvider);

    // No account means no server to name. An empty string means a server
    // too old to say, which is not a mismatch either.
    final server = sync.connected ? sync.serverVersion : null;
    final serverBuild = sync.connected
        ? ref.watch(serverBuildProvider).value
        : null;
    final appLabel = app?.toString() ?? '—';
    final named = server != null && server.isNotEmpty;

    // Only where a reload is the fix. On Android, being behind the server
    // is ordinary and the update tile above already offers the download.
    final stale = ref.watch(servedByServerProvider) && appIsBehind(app, server);

    // The day only, in the reader's own format: the hour a build ran is
    // nothing a person compares.
    String day(DateTime at) => DateFormat.yMMMd(locale).format(at.toLocal());
    final buildLine = [
      if (number.isEmpty)
        l.aboutBuild(build.channel)
      else
        l.aboutBuildNumbered(build.channel, number),
      if (build.builtAt != null) day(build.builtAt!),
      ?build.shortCommit,
    ].join(' · ');
    final serverParts = [
      if (serverBuild?.builtAt != null) day(serverBuild!.builtAt!),
      ?serverBuild?.shortCommit,
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Future<void> copy() async {
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(
        ClipboardData(
          text: details(
            app: app,
            buildNumber: number,
            build: build,
            platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
            serverVersion: server,
            server: serverBuild,
          ),
        ),
      );
      messenger
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.aboutCopied)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: const Key('about-tile'),
          leading: stale
              ? Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                )
              : const NemoLogoTile(),
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
              Text(buildLine, key: const Key('about-build'), style: muted),
              if (serverParts.isNotEmpty)
                Text(
                  l.aboutServerBuild(serverParts.join(' · ')),
                  key: const Key('about-server-build'),
                  style: muted,
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
          onTap: () => showAboutDialog(
            context: context,
            applicationName: l.appName,
            applicationVersion: '$appLabel\n$buildLine',
            applicationIcon: const NemoLogoTile(size: 48),
            applicationLegalese: l.aboutLegalese,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 0, 16, 0),
          child: Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: const Key('about-copy'),
                onPressed: copy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l.aboutCopyDetails),
              ),
              TextButton.icon(
                key: const Key('about-source'),
                onPressed: () => ref.read(openUrlProvider)(sourceUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(l.aboutSourceCode),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
