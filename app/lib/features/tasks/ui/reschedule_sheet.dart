import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Moves [task] to another day without opening it: today, tomorrow, a week
/// from today, a picked date, or none. A time of day it already has is kept.
/// Offers undo, since it is one tap on a sheet away from a wrong day.
Future<void> showRescheduleSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final l = L.of(context);
  final now = ref.read(nowProvider)();
  final messenger = ScaffoldMessenger.of(context);
  final locale = Localizations.localeOf(context).toString();
  final repo = ref.read(tasksRepositoryProvider);
  final current = task.dueAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(task.dueAt!);

  int dueOn(DateTime day) => task.dueHasTime && current != null
      ? composeDue(day, hour: current.hour, minute: current.minute)
      : dayStartMs(day);
  DateTime inDays(int days) =>
      DateTime.fromMillisecondsSinceEpoch(dayStartMsFrom(now, days));

  // null means "clear the date"; a missing answer means the sheet was
  // dismissed.
  final picked = await showModalBottomSheet<({DateTime? day})>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l.rescheduleTitle,
              style: Theme.of(sheet).textTheme.titleMedium,
            ),
          ),
          for (final (key, icon, label, days) in [
            ('today', Icons.today_rounded, l.dateToday, 0),
            ('tomorrow', Icons.wb_sunny_outlined, l.dateTomorrow, 1),
            ('next-week', Icons.date_range_rounded, l.rescheduleNextWeek, 7),
          ])
            ListTile(
              key: Key('reschedule-$key'),
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(sheet, (day: inDays(days))),
            ),
          ListTile(
            key: const Key('reschedule-pick'),
            leading: const Icon(Icons.edit_calendar_rounded),
            title: Text(l.reschedulePick),
            onTap: () async {
              final day = await showDatePicker(
                context: sheet,
                initialDate: current ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (day != null && sheet.mounted) {
                Navigator.pop(sheet, (day: day));
              }
            },
          ),
          if (task.dueAt != null)
            ListTile(
              key: const Key('reschedule-clear'),
              leading: const Icon(Icons.event_busy_rounded),
              title: Text(l.tasksClearDue),
              onTap: () => Navigator.pop(sheet, (day: null)),
            ),
        ],
      ),
    ),
  );
  if (picked == null) return;

  final day = picked.day;
  final moved = day == null
      ? task.copyWith(dueAt: null, dueHasTime: false, remind: false)
      : task.copyWith(dueAt: dueOn(day));
  await repo.save(moved);
  final dueAt = moved.dueAt;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          dueAt == null
              ? l.rescheduleCleared
              : l.rescheduleMoved(
                  dueLabel(
                    l,
                    locale,
                    dueAt: dueAt,
                    hasTime: moved.dueHasTime,
                    now: now,
                  ),
                ),
        ),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () => repo.save(
            moved.copyWith(
              dueAt: task.dueAt,
              dueHasTime: task.dueHasTime,
              remind: task.remind,
            ),
          ),
        ),
      ),
    );
}
