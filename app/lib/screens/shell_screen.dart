import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/lists/ui/list_edit_sheet.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/lists/ui/lists_screen.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_detail_screen.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/app_shortcuts.dart';
import 'package:nemo_core/nemo_core.dart';

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
      return AppShortcuts(
        onGo: go,
        child: Scaffold(
          body: Row(
            children: [
              if (mac)
                _Sidebar(
                  items: items,
                  selected: index,
                  location: location,
                  onSelected: go,
                )
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
                child: location == Routes.notes
                    ? child
                    : MaxWidth(child: child),
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
    return AppShortcuts(
      onGo: go,
      child: Scaffold(
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
      ),
    );
  }
}

/// The macOS style's navigation, laid out as Reminders lays out its own: a
/// search field, a tile with a count for each destination, the lists below
/// with theirs, and a way to add one at the foot beside the account and
/// Settings. A panel floating just inside the window, as in macOS 26.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.location,
    required this.onSelected,
  });

  static const width = 248.0;

  final List<
    ({IconData icon, IconData selectedIcon, String label, String path})
  >
  items;
  final int selected;
  final String location;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    int open(List<Task>? tasks) => tasks?.where((t) => !t.done).length ?? 0;
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    // A list's own page is shown under its row, not the Lists tile.
    final openList = location.startsWith('${Routes.lists}/')
        ? location.substring(Routes.lists.length + 1).split('/').first
        : null;
    final tiles = [
      (0, nemo.listColor(1), open(ref.watch(todayTasksProvider).value)),
      (1, nemo.listColor(4), open(ref.watch(upcomingTasksProvider).value)),
      (2, nemo.listColor(7), lists.length),
      (3, nemo.listColor(5), ref.watch(allNotesProvider).value?.length ?? 0),
    ];
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const NemoMark(size: 20),
                const SizedBox(width: 8),
                Text(L.of(context).appName, style: text.titleSmall),
              ],
            ),
          ),
          // Search is a field at the top of a Mac sidebar, not a place.
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Material(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: const Key('sidebar-search'),
                borderRadius: BorderRadius.circular(8),
                mouseCursor: SystemMouseCursors.text,
                onTap: () => onSelected(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 16,
                        color: selected == 4
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        items[4].label,
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.75,
              children: [
                for (final (i, color, count) in tiles)
                  _SidebarTile(
                    key: Key('sidebar-tile-$i'),
                    icon: items[i].selectedIcon,
                    label: items[i].label,
                    color: color,
                    count: count,
                    selected: openList == null && selected == i,
                    onTap: () => onSelected(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Text(
              l.sidebarMyLists,
              style: text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final list in lists)
                  _SidebarListRow(list: list, selected: list.id == openList),
              ],
            ),
          ),
          Divider(height: 0.5, color: nemo.separator),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                // Gives way before the buttons beside it do: a long word
                // for "New list" shortens rather than pushing them out.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('sidebar-new-list'),
                      onPressed: () => showListEditSheet(context),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        l.listsNewList,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const AccountAction(inRail: true),
                IconButton(
                  tooltip: l.navSettings,
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

/// One of the sidebar's destinations as Reminders draws its smart lists:
/// the icon on a disc of its colour, the count, the name; the chosen one
/// filled with its colour.
class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final light = Theme.of(context).brightness == Brightness.light;
    final ink = selected ? Colors.white : scheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? color
            : light
            ? Colors.white
            : scheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        elevation: selected || !light ? 0 : 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          mouseCursor: context.clickCursor,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 14,
                        color: selected ? color : Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$count',
                      style: text.titleMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    color: selected ? Colors.white : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list under My Lists: its icon on a disc of its colour, its name, its
/// open count; a right click for its menu, as on the Lists page.
class _SidebarListRow extends ConsumerWidget {
  const _SidebarListRow({required this.list, required this.selected});

  final TaskList list;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = context.nemoColors.listColor(list.color);
    final open = ref.watch(openTaskCountProvider(list.id)).value ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? context.nemoColors.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: Key('sidebar-list-${list.id}'),
            borderRadius: BorderRadius.circular(8),
            mouseCursor: context.clickCursor,
            onTap: () {
              ref.read(selectedTaskProvider.notifier).select(null);
              context.go(Routes.list(list.id));
            },
            onSecondaryTapUp: list.isInbox
                ? null
                : (d) => showListMenu(context, ref, list, at: d.globalPosition),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      listIcon(list.icon),
                      size: 13,
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      list.isInbox ? l.listsInbox : list.name,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    '$open',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
