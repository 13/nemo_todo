import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/sync/ui/sync_refresh.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Open tasks due after today, one section per day for a week, then Later,
/// then a collapsible "No date" section for open tasks with no due date at
/// all.
class UpcomingScreen extends ConsumerWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final dated = ref.watch(upcomingTasksProvider);
    final noDate = ref.watch(noDateTasksProvider);
    final collapsed = ref.watch(noDateCollapsedProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navUpcoming),
        actions: const [AccountAction(), SettingsAction()],
      ),
      body: AsyncBody(
        // Three independent streams over the same local database; combined
        // into one value so the screen shows a single loading/error state
        // rather than one section appearing before the others have
        // resolved -- collapsed included, so the No date section never
        // flashes expanded before its stored collapsed state is in.
        value: _combine(dated, noDate, collapsed),
        data: (items) {
          if (items.dated.isEmpty && items.noDate.isEmpty) {
            return SyncRefresh.scrollable(
              child: EmptyState(
                icon: Icons.event_available_outlined,
                message: l.upcomingEmpty,
              ),
            );
          }
          final byDay = <int, List<Task>>{};
          final later = <Task>[];
          for (final t in items.dated) {
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
                  DateTime(now.year, now.month, now.day + days),
                  now,
                ),
                tasks: byDay[days]!,
              ),
            TaskSection(title: l.upcomingLater, tasks: later),
            TaskSection(
              title: l.upcomingNoDate,
              tasks: items.noDate,
              collapsible: true,
              collapsed: items.collapsed,
              onToggle: () => ref
                  .read(kvStoreProvider)
                  .set(noDateCollapsedKey, items.collapsed ? '0' : '1'),
            ),
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

/// Waits for [dated], [noDate] and [collapsed] to have all emitted at
/// least once, rather than showing one section before another (or the
/// No date section before its collapsed state) has resolved.
AsyncValue<({List<Task> dated, List<Task> noDate, bool collapsed})> _combine(
  AsyncValue<List<Task>> dated,
  AsyncValue<List<Task>> noDate,
  AsyncValue<bool> collapsed,
) {
  if (dated.hasValue && noDate.hasValue && collapsed.hasValue) {
    return AsyncValue.data((
      dated: dated.value!,
      noDate: noDate.value!,
      collapsed: collapsed.value!,
    ));
  }
  final failed = dated.hasError
      ? dated
      : (noDate.hasError ? noDate : (collapsed.hasError ? collapsed : null));
  if (failed != null) {
    return AsyncValue.error(failed.error!, failed.stackTrace!);
  }
  return const AsyncValue.loading();
}
