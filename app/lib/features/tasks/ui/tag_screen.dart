import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/sync/ui/sync_refresh.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Every task with one tag, across all lists.
class TagScreen extends ConsumerWidget {
  const TagScreen({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final tasks = ref.watch(tasksByTagProvider(tag));
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.search),
        ),
        title: Text('#$tag'),
        actions: const [AccountAction(), SettingsAction()],
      ),
      body: AsyncBody(
        value: tasks,
        data: (items) => items.isEmpty
            ? SyncRefresh.scrollable(
                child: EmptyState(
                  icon: Icons.tag_rounded,
                  message: l.tagEmpty(tag),
                ),
              )
            : TaskListView(
                showList: true,
                sections: [
                  TaskSection(
                    title: l.tasksOpen,
                    tasks: items.where((t) => !t.done).toList(),
                  ),
                ],
                completed: items.where((t) => t.done).toList(),
              ),
      ),
    );
  }
}
