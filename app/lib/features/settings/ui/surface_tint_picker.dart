import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/surface_tint.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// How much of the accent nemo's backgrounds take on; only the nemo style
/// has it, so elsewhere this is nothing.
class SurfaceTintPicker extends ConsumerWidget {
  const SurfaceTintPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appStyleControllerProvider) != AppStyle.nemo) {
      return const SizedBox.shrink();
    }
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.settingsSurfaceTint,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SegmentedButton<SurfaceTint>(
            key: const Key('surface-tint'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: SurfaceTint.none,
                label: Text(l.surfaceTintNone),
              ),
              ButtonSegment(
                value: SurfaceTint.subtle,
                label: Text(l.surfaceTintSubtle),
              ),
              ButtonSegment(
                value: SurfaceTint.strong,
                label: Text(l.surfaceTintStrong),
              ),
            ],
            selected: {ref.watch(surfaceTintControllerProvider)},
            onSelectionChanged: (s) =>
                ref.read(surfaceTintControllerProvider.notifier).set(s.first),
          ),
        ],
      ),
    );
  }
}
