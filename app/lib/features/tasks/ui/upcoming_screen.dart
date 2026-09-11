import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Open tasks due after today, one section per day for a week, then Later.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final tasks = ref.watch(upcomingTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navUpcoming),
        actions: const [AccountAction(), SettingsAction()],
      ),
      body: AsyncBody(
        value: tasks,
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.event_available_outlined,
              message: l.upcomingEmpty,
            );
          }
          final byDay = <int, List<Task>>{};
          final later = <Task>[];
          for (final t in items) {
            final days = daysFromToday(t.dueAt!, now);
            if (days <= 7) {
              byDay.putIfAbsent(days, () => []).add(t);
            } else {
              later.add(t);
            }
          }
          final sections = [
            for (final days in byDay.keys.toList()..sort())
              TaskSection(
                title: dayHeader(
                  l,
                  locale,
                  startOfDay(now).add(Duration(days: days)),
                  now,
                ),
                tasks: byDay[days]!,
              ),
            TaskSection(title: l.upcomingLater, tasks: later),
          ];
          return TaskListView(sections: sections, showList: true);
        },
      ),
      bottomNavigationBar: QuickAddBar(
        listId: null,
        defaultDueAt: dayStartMsFrom(now, 1),
        showListPicker: true,
      ),
    );
  }
}
