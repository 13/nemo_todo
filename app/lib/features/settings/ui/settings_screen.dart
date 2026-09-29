import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/presentation.dart';
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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Where each section starts, for the Mac sidebar to scroll to.
  final List<GlobalKey<State<StatefulWidget>>> _anchors = List.generate(
    6,
    (_) => GlobalKey(),
  );

  /// The section the Mac sidebar last went to.
  var _current = 0;

  Future<void> _goTo(int section) async {
    setState(() => _current = section);
    final target = _anchors[section].currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    final mac = isMacWindow(context);
    final children = <Widget>[
      KeyedSubtree(
        key: _anchors[0],
        child: SectionHeader(title: l.settingsAppearance),
      ),
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
      KeyedSubtree(key: _anchors[1], child: const CelebrationSettingsSection()),
      KeyedSubtree(key: _anchors[2], child: const SyncSettingsSection()),
      KeyedSubtree(key: _anchors[3], child: const DataTiles()),
      KeyedSubtree(
        key: _anchors[4],
        child: SectionHeader(title: l.settingsTasks),
      ),
      SettingsGroup(
        children: [
          // Only where it does anything; a group has no empty rows.
          if (ref.watch(remindersSupportedProvider)) const DailyListTile(),
          const CurrencyTile(),
          // A window this wide usually has a keyboard to go with it.
          if (MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint)
            ListTile(
              key: const Key('shortcuts-tile'),
              leading: const AppIcon(Icons.keyboard_outlined),
              title: Text(l.shortcutsTitle),
              trailing: const Text('?'),
              onTap: () => showShortcutsHelp(context),
            ),
        ],
      ),
      const UpdateTile(),
      KeyedSubtree(
        key: _anchors[5],
        child: SectionHeader(title: l.settingsAbout),
      ),
      const SettingsGroup(children: [AboutTile()]),
    ];
    final appBar = AppBar(
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.today),
      ),
      title: Text(l.settingsTitle),
    );
    if (!mac) {
      return Scaffold(
        appBar: appBar,
        body: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: children,
          ),
        ),
      );
    }
    // A Mac window lays Settings out as System Settings does: the sections
    // in a sidebar, each with its icon on a coloured tile, the form beside.
    // Built all at once rather than lazily, so every section is there for
    // the sidebar to scroll to.
    final sections = [
      (l.settingsAppearance, Icons.brightness_auto_outlined, 7),
      (l.settingsCelebrations, Icons.celebration_outlined, 3),
      (l.settingsAccount, Icons.account_circle_outlined, 1),
      (l.settingsData, Icons.file_download_outlined, 6),
      (l.settingsTasks, Icons.task_alt, 5),
      (l.settingsAbout, Icons.water_drop_outlined, 0),
    ];
    return Scaffold(
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 244,
            child: ListView(
              key: const Key('settings-sidebar'),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
              children: [
                for (final (i, (label, icon, color)) in sections.indexed)
                  _SectionRow(
                    label: label,
                    icon: icon,
                    color: context.nemoColors.listColor(color),
                    selected: i == _current,
                    onTap: () => _goTo(i),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.nemoColors.separator),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section in the Mac sidebar: its icon white on a rounded tile of its
/// colour, as System Settings draws its panes.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Material(
      color: selected ? context.nemoColors.selection : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        mouseCursor: context.clickCursor,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: AppIcon(icon, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
