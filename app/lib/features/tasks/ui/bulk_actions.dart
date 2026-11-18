import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/tasks/ui/reschedule_sheet.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

// What the selection bar does to the tasks picked on it. Each reads the
// repository and the ScaffoldMessenger before its first write: the tasks
// can leave the screen as they change, and the Undo can be tapped after
// the screen itself is gone, when its `ref` and `context` are unusable.
//
// Each also ends the selection before it writes, which takes the bar away,
// and does nothing when the selection has already ended: a second tap that
// lands before the bar is gone then finds nothing left to do, rather than
// completing, moving or deleting the same tasks twice.

/// Marks [tasks] done, or, when every one of them is done already, not
/// done. Done ones among open ones stay done; a mixed pick means "finish
/// these".
///
/// Only the last completion goes through the celebration, so finishing
/// several at once celebrates once.
Future<void> completeTasks(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  if (tasks.isEmpty || ref.read(taskSelectionProvider) == null) return;
  final l = L.of(context);
  final repo = ref.read(tasksRepositoryProvider);
  final celebrations = ref.read(celebrationControllerProvider);
  final messenger = ScaffoldMessenger.of(context);
  ref.read(taskSelectionProvider.notifier).end();
  final reopen = tasks.every((t) => t.done);
  final changed = reopen ? tasks : tasks.where((t) => !t.done).toList();
  // The next occurrences of repeating tasks the completions put on the
  // list, which Undo takes back.
  final spawned = <String>[];
  if (reopen) {
    for (final task in changed) {
      await repo.setDone(task.id, done: false);
    }
  } else {
    for (final task in changed.take(changed.length - 1)) {
      final next = await repo.setDone(task.id, done: true);
      if (next != null) spawned.add(next);
    }
    // The snackbar carries the message, so no pill on top of it.
    final last = await completeTaskWith(
      repo,
      celebrations,
      changed.last,
      done: true,
      showPill: false,
    );
    if (last.spawned case final next?) spawned.add(next);
  }
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          reopen
              ? l.tasksUndoneMany(changed.length)
              : l.tasksCompletedMany(changed.length),
        ),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () async {
            for (final task in changed) {
              // Putting a reopened task back as it was, rather than ticking
              // it again, which would bring a repeating one back twice.
              await (reopen
                  ? repo.save(task)
                  : repo.setDone(task.id, done: false));
            }
            for (final id in spawned) {
              await repo.delete(id);
            }
          },
        ),
      ),
    );
}

/// Moves [tasks] to a day picked on the reschedule sheet, or clears their
/// dates, the way [showRescheduleSheet] moves one: a time of day a task
/// has is kept. Does nothing, and keeps selecting, if the sheet is
/// dismissed.
Future<void> rescheduleTasks(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  if (tasks.isEmpty || _picking || ref.read(taskSelectionProvider) == null) {
    return;
  }
  final l = L.of(context);
  final now = ref.read(nowProvider)();
  final locale = Localizations.localeOf(context).toString();
  final repo = ref.read(tasksRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final selection = ref.read(taskSelectionProvider.notifier);
  // The selection stays while the sheet is up, so a dismissed sheet leaves
  // it as it was; this keeps a second tap from opening a second sheet.
  _picking = true;
  final ({DateTime? day})? picked;
  try {
    picked = await pickRescheduleDay(
      context,
      ref,
      canClear: tasks.any((t) => t.dueAt != null),
    );
  } finally {
    _picking = false;
  }
  if (picked == null) return;
  selection.end();

  // The tasks as they are now rather than as the bar saw them before the
  // sheet went up: a change that arrived meanwhile, as from another
  // device, is kept, and a task deleted meanwhile stays deleted.
  final current = [for (final task in tasks) ?await repo.find(task.id)];
  if (current.isEmpty) return;
  final day = picked.day;
  final moved = [
    for (final task in current)
      if (day == null)
        task.copyWith(dueAt: null, dueHasTime: false, remind: false)
      else
        task.copyWith(dueAt: _dueOn(task, day)),
  ];
  for (final task in moved) {
    await repo.save(task);
  }
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          day == null
              ? l.rescheduleClearedMany(moved.length)
              : l.rescheduleMovedMany(
                  moved.length,
                  dueLabel(
                    l,
                    locale,
                    dueAt: dayStartMs(day),
                    hasTime: false,
                    now: now,
                  ),
                ),
        ),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () async {
            // Only the dates go back, onto each task as it is by then, and
            // one deleted since is left deleted.
            for (final before in current) {
              final latest = await repo.find(before.id);
              if (latest == null) continue;
              await repo.save(
                latest.copyWith(
                  dueAt: before.dueAt,
                  dueHasTime: before.dueHasTime,
                  remind: before.remind,
                ),
              );
            }
          },
        ),
      ),
    );
}

/// Whether a Move's sheet is up.
var _picking = false;

/// [day], at the time of day [task] is due if it has one.
int _dueOn(Task task, DateTime day) {
  final dueAt = task.dueAt;
  if (!task.dueHasTime || dueAt == null) return dayStartMs(day);
  final current = DateTime.fromMillisecondsSinceEpoch(dueAt);
  return composeDue(day, hour: current.hour, minute: current.minute);
}

/// Deletes [tasks] and offers undo, as a single task's delete does.
Future<void> deleteTasksWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<Task> tasks,
) async {
  if (tasks.isEmpty || ref.read(taskSelectionProvider) == null) return;
  final l = L.of(context);
  final repo = ref.read(tasksRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  ref.read(taskSelectionProvider.notifier).end();
  for (final task in tasks) {
    await repo.delete(task.id);
  }
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.tasksDeletedMany(tasks.length)),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () async {
            for (final task in tasks) {
              await repo.restore(task.id);
            }
          },
        ),
      ),
    );
}
