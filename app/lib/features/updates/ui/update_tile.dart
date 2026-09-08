import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The Settings entry: which version is running, and one action for
/// whatever the updater is doing.
class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  String _errorText(L l, UpdateFailure failure) => switch (failure) {
    UpdateFailure.network => l.updatesErrorNetwork,
    UpdateFailure.rateLimited => l.updatesErrorRateLimited,
    UpdateFailure.notFound => l.updatesErrorNotFound,
    UpdateFailure.malformed => l.updatesErrorMalformed,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(updatesSupportedProvider)) return const SizedBox.shrink();
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(updateControllerProvider);
    final notifier = ref.read(updateControllerProvider.notifier);
    final version = ref.watch(currentVersionProvider).value;

    final (String subtitle, Color subtitleColor) = switch (state) {
      UpdateChecking() => (l.updatesChecking, scheme.onSurfaceVariant),
      UpToDate() => (l.updatesUpToDate, scheme.onSurfaceVariant),
      UpdateAvailable(:final release) => (
        l.updatesAvailable(release.version.toString()),
        scheme.primary,
      ),
      UpdateDownloading(:final progress) => (
        l.updatesDownloading(progress < 0 ? 0 : (progress * 100).round()),
        scheme.onSurfaceVariant,
      ),
      UpdateReady() => (l.updatesInstallHint, scheme.onSurfaceVariant),
      UpdateFailed(:final failure) => (_errorText(l, failure), scheme.error),
      UpdateIdle() => (
        version == null
            ? l.updatesCheckNow
            : l.updatesCurrentVersion(version.toString()),
        scheme.onSurfaceVariant,
      ),
    };

    final trailing = switch (state) {
      UpdateChecking() => const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      UpdateDownloading(:final progress) => SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress < 0 ? null : progress,
        ),
      ),
      UpdateAvailable() => FilledButton(
        key: const Key('download-update'),
        onPressed: notifier.download,
        child: Text(l.updatesDownload),
      ),
      UpdateReady() => FilledButton(
        key: const Key('install-update'),
        onPressed: notifier.install,
        child: Text(l.updatesInstall),
      ),
      _ => IconButton(
        key: const Key('check-for-updates'),
        tooltip: l.updatesCheckNow,
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () => notifier.check(manual: true),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.updatesTitle),
        ListTile(
          leading: const Icon(Icons.system_update_alt_rounded),
          title: Text(
            version == null
                ? l.updatesTitle
                : l.updatesCurrentVersion(version.toString()),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
          trailing: trailing,
        ),
        if (state is UpdateAvailable && state.release.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.updatesWhatsNew,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  state.release.notes,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
