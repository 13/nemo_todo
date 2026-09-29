import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/add_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/lists/ui/list_edit_sheet.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/sync/ui/sync_refresh.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// All lists as cards; the Inbox always comes first.
class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final lists = ref.watch(allListsProvider);
    final sharing = ref.watch(listMetaProvider).value ?? const {};
    final add = AddAction(
      buttonKey: const Key('new-list'),
      label: l.listsNewList,
      onPressed: () => showListEditSheet(context),
      extended: true,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.listsTitle),
        actions: [
          ?add.toolbar(context),
          const AccountAction(),
          const SettingsAction(),
        ],
      ),
      body: AsyncBody(
        value: lists,
        data: (items) => SyncRefresh(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListCard(
                    list: items[i],
                    shared: sharing[items[i].id]?.isShared ?? false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: add.fab(context),
    );
  }
}

class ListCard extends ConsumerWidget {
  const ListCard({required this.list, this.shared = false, super.key});

  final TaskList list;
  final bool shared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    final scheme = Theme.of(context).colorScheme;
    final color = nemo.listColor(list.color);
    final open = ref.watch(openTaskCountProvider(list.id)).value ?? 0;
    final name = list.isInbox ? l.listsInbox : list.name;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('list-card-${list.id}'),
        onTap: () => context.push(Routes.list(list.id)),
        onLongPress: list.isInbox
            ? null
            : () => showListMenu(context, ref, list),
        onSecondaryTapUp: list.isInbox
            ? null
            : (d) => showListMenu(context, ref, list, at: d.globalPosition),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // macOS, like Reminders: the glyph on a disc of the colour.
                  if (context.appStyle == AppStyle.macos)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        listIcon(list.icon),
                        size: 20,
                        color:
                            ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(listIcon(list.icon), color: color, size: 20),
                    ),
                  const Spacer(),
                  if (shared)
                    Tooltip(
                      message: l.listsShared,
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                l.listsOpenCount(open),
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit / members / delete actions for a list: as a sheet from a long
/// press, or as a menu [at] the pointer from a right click.
Future<void> showListMenu(
  BuildContext context,
  WidgetRef ref,
  TaskList list, {
  Offset? at,
}) async {
  final l = L.of(context);
  final error = Theme.of(context).colorScheme.error;
  final entries = [
    ('edit', Icons.edit_outlined, l.commonEdit, null),
    ('members', Icons.people_outline_rounded, l.listsMembers, null),
    ('delete', Icons.delete_outline_rounded, l.commonDelete, error),
  ];
  final String? action;
  if (at != null) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final (value, icon, label, color) in entries)
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: color)),
              ],
            ),
          ),
      ],
    );
  } else {
    action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, icon, label, color) in entries)
              ListTile(
                leading: Icon(icon, color: color),
                title: Text(label, style: TextStyle(color: color)),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
  }
  if (!context.mounted) return;
  switch (action) {
    case 'edit':
      await showListEditSheet(context, list: list);
    case 'members':
      await context.push(Routes.members(list.id));
    case 'delete':
      await confirmDeleteList(context, ref, list);
  }
}

/// Asks, deletes, and offers undo. Returns true when deleted.
Future<bool> confirmDeleteList(
  BuildContext context,
  WidgetRef ref,
  TaskList list,
) async {
  final l = L.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.commonDelete),
      content: Text(l.listsDeleteConfirm(list.name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final repo = ref.read(listsRepositoryProvider);
  await repo.delete(list.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.listsDeleted),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () => repo.restore(list.id),
        ),
      ),
    );
  }
  return true;
}
