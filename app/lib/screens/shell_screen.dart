import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_detail_screen.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Adaptive chrome around the main destinations: a bottom navigation bar on
/// phones, a navigation rail from 840 dp, and from 1200 dp a second pane
/// holding whichever task is open. Content is centred and capped so the web
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
    if (location.startsWith(Routes.search)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = destinations(context);
    final index = indexFor(GoRouterState.of(context).matchedLocation);
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

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              groupAlignment: -0.9,
              leading: const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: NemoLogoTile(),
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
            const VerticalDivider(width: 1),
            Expanded(child: MaxWidth(child: child)),
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

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
