import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/tasks/ui/reschedule_sheet.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// Deletes [task] and offers undo, the way a swipe and the menu both do.
Future<void> deleteTaskWithUndo(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final l = L.of(context);
  final repo = ref.read(tasksRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  await repo.delete(task.id);
  messenger.showSnackBar(
    SnackBar(
      content: Text(l.tasksDeleted),
      // An action would keep it up until tapped.
      persist: false,
      action: SnackBarAction(
        label: l.commonUndo,
        onPressed: () => repo.restore(task.id),
      ),
    ),
  );
}

/// What a task's context menu offers: what a swipe and a long press do on
/// a phone, for a mouse, which has neither.
Future<void> showTaskMenu(
  BuildContext context,
  WidgetRef ref,
  Task task,
  Offset at,
) async {
  final l = L.of(context);
  final error = Theme.of(context).colorScheme.error;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  PopupMenuItem<String> item(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      at & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (task.done)
        item('done', Icons.undo_rounded, l.taskMenuUndone)
      else
        item('done', Icons.check_rounded, l.taskMenuDone),
      item('move', Icons.event_rounded, l.taskMenuMove),
      const PopupMenuDivider(),
      item(
        'delete',
        Icons.delete_outline_rounded,
        l.commonDelete,
        color: error,
      ),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case 'done':
      await completeTask(ref, task, done: !task.done);
    case 'move':
      await showRescheduleSheet(context, ref, task);
    case 'delete':
      await deleteTaskWithUndo(context, ref, task);
  }
}
