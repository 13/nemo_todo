import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_screen.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// One of the sidebar's destinations as Reminders draws its smart lists:
/// the icon on a disc of its colour, the count, the name; the chosen one
/// filled with its colour.
class SidebarTile extends StatelessWidget {
  const SidebarTile({
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
                      child: AppIcon(
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
class SidebarListRow extends ConsumerWidget {
  const SidebarListRow({required this.list, required this.selected, super.key});

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
                    child: AppIcon(
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
