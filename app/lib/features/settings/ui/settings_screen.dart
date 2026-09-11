import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/settings/ui/about_tile.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_settings_section.dart';
import 'package:nemo/features/updates/ui/update_tile.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.today),
        ),
        title: Text(l.settingsTitle),
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SectionHeader(title: l.settingsAppearance),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                key: const Key('theme-mode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l.themeSystem),
                    icon: const Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l.themeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l.themeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeControllerProvider.notifier).set(s.first),
              ),
            ),
            const SyncSettingsSection(),
            const UpdateTile(),
            SectionHeader(title: l.settingsAbout),
            const AboutTile(),
          ],
        ),
      ),
    );
  }
}
