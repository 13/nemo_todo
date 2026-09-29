import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/new_task_button.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/core/widgets/style_scaffold.dart';
import 'package:nemo/features/lists/ui/list_edit_sheet.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/lists/ui/lists_screen.dart';
import 'package:nemo/features/lists/ui/task_order_picker.dart';
import 'package:nemo/features/sync/ui/sync_refresh.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';
import 'package:nemo_core/nemo_core.dart';

/// One list's tasks in the list's own order with quick add at the bottom.
class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    final list = ref.watch(listByIdProvider(listId)).value;
    final tasks = ref.watch(tasksByListProvider(listId));
    final sharing = ref.watch(listMetaProvider).value?[listId];
    if (list == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    // With the macOS sidebar beside it, the list is one of its rows: there
    // is nothing to go back to.
    final besideSidebar =
        context.appStyle == AppStyle.macos &&
        MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint;
    final actions = <Widget>[
      if (sharing?.isShared ?? false)
        IconButton(
          tooltip: l.listsMembers,
          icon: const AppIcon(Icons.people_outline_rounded),
          onPressed: () => context.push(Routes.members(listId)),
        ),
      PopupMenuButton<String>(
        key: const Key('list-menu'),
        onSelected: (action) async {
          switch (action) {
            case 'edit':
              await showListEditSheet(context, list: list);
            case 'members':
              await context.push(Routes.members(listId));
            case 'sort':
              await chooseTaskOrder(context, ref, list);
            case 'delete':
              if (await confirmDeleteList(context, ref, list) &&
                  context.mounted) {
                context.go(Routes.lists);
              }
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
          PopupMenuItem(value: 'members', child: Text(l.listsMembers)),
          if (sharing?.isOwner ?? true)
            PopupMenuItem(value: 'sort', child: Text(l.listsSortBy)),
          if (!list.isInbox)
            PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
        ],
      ),
    ];
    final name = list.isInbox ? l.listsInbox : list.name;
    final material = context.appStyle == AppStyle.material;
    return StyleScaffold(
      title: name,
      leading: BackButton(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.lists),
      ),
      actions: actions,
      appBar: AppBar(
        automaticallyImplyLeading: !besideSidebar,
        leading: besideSidebar
            ? null
            : BackButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.lists),
              ),
        // macOS names the list in its own colour, large, as Reminders
        // does; elsewhere its icon goes beside the name.
        title: context.appStyle == AppStyle.macos
            ? Text(
                list.isInbox ? l.listsInbox : list.name,
                key: const Key('list-title'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: nemo.listColor(list.color)),
              )
            : Row(
                children: [
                  AppIcon(
                    listIcon(list.icon),
                    color: nemo.listColor(list.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      list.isInbox ? l.listsInbox : list.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        actions: actions,
      ),
      body: AsyncBody(
        value: tasks,
        data: (items) {
          if (items.isEmpty) {
            return SyncRefresh.scrollable(
              child: EmptyState(
                icon: listIcon(list.icon),
                message: l.tasksEmptyList,
              ),
            );
          }
          final order = list.order;
          final sorted = sortTasks(items, order);
          // Only a hand-made order can be changed by hand: in any other,
          // a dragged task would just fall back where the sort puts it.
          return TaskListView(
            reorderable: order == TaskOrder.manual,
            header: order == TaskOrder.manual
                ? null
                : TaskOrderBanner(list: list),
            sections: [
              TaskSection(
                title: l.tasksOpen,
                tasks: sorted.where((t) => !t.done).toList(),
              ),
            ],
            completed: sorted.where((t) => t.done).toList(),
          );
        },
      ),
      bottomNavigationBar: material ? null : QuickAddBar(listId: listId),
      floatingActionButton: material ? NewTaskButton(listId: listId) : null,
    );
  }
}
