import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/celebrations/ui/celebration_settings_section.dart';
import 'package:nemo/features/settings/ui/about_tile.dart';
import 'package:nemo/features/settings/ui/accent_picker.dart';
import 'package:nemo/features/settings/ui/currency_tile.dart';
import 'package:nemo/features/settings/ui/daily_list_tile.dart';
import 'package:nemo/features/settings/ui/data_tiles.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_settings_section.dart';
import 'package:nemo/features/updates/ui/update_tile.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/app_shortcuts.dart';
import 'package:nemo/screens/shell_screen.dart';

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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SegmentedButton<AppStyle>(
                key: const Key('app-style'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: AppStyle.nemo,
                    label: Text(l.styleNemo),
                    icon: const AppIcon(Icons.water_drop_outlined),
                  ),
                  ButtonSegment(
                    value: AppStyle.macos,
                    label: Text(l.styleMacos),
                    icon: const AppIcon(Icons.laptop_mac_outlined),
                  ),
                  ButtonSegment(
                    value: AppStyle.material,
                    label: Text(l.styleMaterial),
                    icon: const AppIcon(Icons.android_rounded),
                  ),
                ],
                selected: {ref.watch(appStyleControllerProvider)},
                onSelectionChanged: (s) =>
                    ref.read(appStyleControllerProvider.notifier).set(s.first),
              ),
            ),
            const AccentPicker(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                key: const Key('theme-mode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l.themeSystem),
                    icon: const AppIcon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l.themeLight),
                    icon: const AppIcon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l.themeDark),
                    icon: const AppIcon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeControllerProvider.notifier).set(s.first),
              ),
            ),
            const CelebrationSettingsSection(),
            const SyncSettingsSection(),
            const DataTiles(),
            SectionHeader(title: l.settingsTasks),
            const DailyListTile(),
            const CurrencyTile(),
            const UpdateTile(),
            // A window this wide usually has a keyboard to go with it.
            if (MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint)
              ListTile(
                key: const Key('shortcuts-tile'),
                leading: const AppIcon(Icons.keyboard_outlined),
                title: Text(l.shortcutsTitle),
                trailing: const Text('?'),
                onTap: () => showShortcutsHelp(context),
              ),
            SectionHeader(title: l.settingsAbout),
            const AboutTile(),
          ],
        ),
      ),
    );
  }
}
