import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/features/updates/ui/update_banner.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';

/// Overdue and today's tasks across all lists, plus what got done today.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final tasks = ref.watch(todayTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.navToday),
            Text(
              longDate(locale, now),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: const [AccountAction(), SettingsAction()],
      ),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: AsyncBody(
              value: tasks,
              data: (items) {
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.wb_sunny_outlined,
                    message: l.todayEmpty,
                  );
                }
                final overdue = items
                    .where(
                      (t) =>
                          !t.done &&
                          isOverdue(
                            dueAt: t.dueAt,
                            hasTime: t.dueHasTime,
                            now: now,
                          ),
                    )
                    .toList();
                final today = items
                    .where((t) => !t.done && !overdue.contains(t))
                    .toList();
                final done = items.where((t) => t.done).toList();
                return TaskListView(
                  showList: true,
                  sections: [
                    TaskSection(
                      title: l.todayOverdue,
                      tasks: overdue,
                      color: context.nemoColors.overdue,
                    ),
                    TaskSection(title: l.navToday, tasks: today),
                  ],
                  completed: done,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: QuickAddBar(
        listId: null,
        defaultDueAt: dayStartMs(now),
        showListPicker: true,
      ),
    );
  }
}
