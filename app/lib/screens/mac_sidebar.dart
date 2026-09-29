import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/features/lists/ui/list_edit_sheet.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/mac_sidebar_rows.dart';
import 'package:nemo_core/nemo_core.dart';

/// The macOS style's navigation, laid out as Reminders lays out its own: a
/// search field, a tile with a count for each destination, the lists below
/// with theirs, and a way to add one at the foot beside the account and
/// Settings. A panel floating just inside the window, as in macOS 26.
class MacSidebar extends ConsumerWidget {
  const MacSidebar({
    required this.items,
    required this.selected,
    required this.location,
    required this.onSelected,
    super.key,
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
                Flexible(
                  child: Text(
                    L.of(context).appName,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
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
                      AppIcon(
                        Icons.search_rounded,
                        size: 16,
                        color: selected == 4
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          items[4].label,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
            child: GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: SidebarTile.height(context),
              ),
              children: [
                for (final (i, color, count) in tiles)
                  SidebarTile(
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
                  SidebarListRow(list: list, selected: list.id == openList),
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
                      icon: const AppIcon(
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
                  icon: const AppIcon(Icons.settings_outlined),
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
