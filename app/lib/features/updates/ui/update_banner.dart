import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// One line above the task list, and only when there is genuinely a newer
/// version. Dismissing it silences that version, not the next one.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    if (state is! UpdateAvailable) return const SizedBox.shrink();
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: const Key('update-banner'),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.system_update_alt_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.updatesAvailable(state.release.version.toString()),
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => context.push(Routes.settings),
              child: Text(l.updatesDownload),
            ),
            IconButton(
              key: const Key('update-banner-dismiss'),
              tooltip: l.updatesLater,
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: ref.read(updateControllerProvider.notifier).dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
