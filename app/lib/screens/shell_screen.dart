import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_detail_screen.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Adaptive chrome around the main destinations: a bottom navigation bar on
/// phones, a navigation rail from 840 dp -- in the macOS style, a floating
/// sidebar -- and from 1200 dp a second pane holding whichever task is
/// open. Content is centred and capped so the web
/// app reads like the phone app.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.child, super.key});

  final Widget child;

  static const railBreakpoint = 840.0;

  /// Where a window stops being one column of content. Below this a task
  /// opens as a page; above it, beside the list it came from.
  static const splitBreakpoint = 1200.0;

  /// How much of a wide window the open task takes.
  static const detailPaneWidth = 460.0;

  static List<
    ({IconData icon, IconData selectedIcon, String label, String path})
  >
  destinations(BuildContext context) {
    final l = L.of(context);
    return [
      (
        icon: Icons.today_outlined,
        selectedIcon: Icons.today,
        label: l.navToday,
        path: Routes.today,
      ),
      (
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: l.navUpcoming,
        path: Routes.upcoming,
      ),
      (
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        label: l.navLists,
        path: Routes.lists,
      ),
      (
        icon: Icons.sticky_note_2_outlined,
        selectedIcon: Icons.sticky_note_2,
        label: l.navNotes,
        path: Routes.notes,
      ),
      (
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: l.navSearch,
        path: Routes.search,
      ),
    ];
  }

  static int indexFor(String location) {
    if (location.startsWith(Routes.today)) return 0;
    if (location.startsWith(Routes.upcoming)) return 1;
    if (location.startsWith(Routes.lists)) return 2;
    if (location.startsWith(Routes.notes)) return 3;
    if (location.startsWith(Routes.search)) return 4;
    // Following a tag is a kind of search.
    if (location.startsWith('/tags/')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = destinations(context);
    final location = GoRouterState.of(context).matchedLocation;
    final index = indexFor(location);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= railBreakpoint;
    final split = width >= splitBreakpoint;
    void go(int i) {
      // The open task belongs to the list it was opened from, so changing
      // destination closes it rather than leaving it beside a list it has
      // nothing to do with.
      ref.read(selectedTaskProvider.notifier).select(null);
      context.go(items[i].path);
    }

    final mac = context.appStyle == AppStyle.macos;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            if (mac)
              _Sidebar(items: items, selected: index, onSelected: go)
            else
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: go,
                groupAlignment: -0.9,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 16),
                  child: NemoMark(size: 40),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const AccountAction(inRail: true),
                          IconButton(
                            tooltip: L.of(context).navSettings,
                            icon: const Icon(Icons.settings_outlined),
                            onPressed: () => context.push(Routes.settings),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final d in items)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            if (!mac) const VerticalDivider(width: 1),
            Expanded(
              // The notes grid wants the width the shell would otherwise
              // cap at 720 to lay out its columns, and caps itself at 1200.
              child: location == Routes.notes ? child : MaxWidth(child: child),
            ),
            if (split) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: detailPaneWidth,
                child: _DetailPane(taskId: ref.watch(selectedTaskProvider)),
              ),
            ],
          ],
        ),
      );
    }

    final bar = NavigationBar(
      selectedIndex: index,
      onDestinationSelected: go,
      destinations: [
        for (final d in items)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
    );
    return Scaffold(
      body: child,
      // A tab bar sits under a hairline rather than on a tonal step.
      bottomNavigationBar: mac
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.nemoColors.separator),
                ),
              ),
              child: bar,
            )
          : bar,
    );
  }
}

/// The macOS style's navigation: a panel floating just inside the window,
/// the app's mark and name at the top, a row per destination, and the
/// account and Settings at the foot, where the rail keeps them too.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  static const width = 232.0;

  final List<
    ({IconData icon, IconData selectedIcon, String label, String path})
  >
  items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final nemo = context.nemoColors;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('mac-sidebar'),
      width: width,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: nemo.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nemo.separator, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Row(
              children: [
                const NemoMark(size: 28),
                const SizedBox(width: 10),
                Text(
                  L.of(context).appName,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _SidebarRow(
              icon: i == selected ? items[i].selectedIcon : items[i].icon,
              label: items[i].label,
              selected: i == selected,
              onTap: () => onSelected(i),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                const AccountAction(inRail: true),
                const Spacer(),
                IconButton(
                  tooltip: L.of(context).navSettings,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push(Routes.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination in [_Sidebar]: the selected one on a soft grey pill with
/// its icon in the accent, the way Finder and Mail mark theirs.
class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? context.nemoColors.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: text?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-hand pane: the open task, or an invitation to open one.
class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.taskId});

  final String? taskId;

  @override
  Widget build(BuildContext context) {
    final id = taskId;
    if (id == null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.splitscreen_outlined,
          message: L.of(context).tasksNoSelection,
        ),
      );
    }
    // Keyed by the task, so opening another one rebuilds the editor rather
    // than carrying the previous task's half-typed title into it.
    return TaskDetailScreen(key: ValueKey(id), taskId: id, embedded: true);
  }
}
