import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/features/lists/ui/list_edit_sheet.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/lists/ui/lists_screen.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// One list's tasks in manual order with quick add at the bottom.
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
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.lists),
        ),
        title: Row(
          children: [
            Icon(listIcon(list.icon), color: nemo.listColor(list.color)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                list.isInbox ? l.listsInbox : list.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (sharing?.isShared ?? false)
            IconButton(
              tooltip: l.listsMembers,
              icon: const Icon(Icons.people_outline_rounded),
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
              if (!list.isInbox)
                PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
            ],
          ),
        ],
      ),
      body: AsyncBody(
        value: tasks,
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: listIcon(list.icon),
              message: l.tasksEmptyList,
            );
          }
          return TaskListView(
            reorderable: true,
            sections: [
              TaskSection(
                title: l.tasksOpen,
                tasks: items.where((t) => !t.done).toList(),
              ),
            ],
            completed: items.where((t) => t.done).toList(),
          );
        },
      ),
      bottomNavigationBar: QuickAddBar(listId: listId),
    );
  }
}
