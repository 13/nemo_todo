import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/due_chip.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

/// One task in a list: round check, title, and a row of small facts.
class TaskTile extends ConsumerWidget {
  const TaskTile({required this.task, this.showList = false, super.key});

  final Task task;
  final bool showList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final now = ref.watch(nowProvider)();
    final progress = ref.watch(subtaskProgressProvider).value?[task.id];
    final list = showList
        ? ref.watch(listByIdProvider(task.listId)).value
        : null;
    final dueAt = task.dueAt;
    final meta = <Widget>[
      if (dueAt != null)
        DueChip(
          dueAt: dueAt,
          hasTime: task.dueHasTime,
          now: now,
          done: task.done,
        ),
      if (list != null)
        MetaChip(
          icon: listIcon(list.icon),
          label: list.name,
          color: nemo.listColor(list.color),
        ),
      if (progress != null && progress.total > 0)
        MetaChip(
          icon: Icons.checklist_rounded,
          label: '${progress.done}/${progress.total}',
        ),
      for (final tag in task.tags)
        MetaChip(icon: Icons.tag_rounded, label: tag),
    ];
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      decoration: task.done ? TextDecoration.lineThrough : null,
      color: task.done ? scheme.onSurfaceVariant : scheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    return InkWell(
      onTap: () => openTask(context, ref, task.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoneCheck(
              done: task.done,
              color: nemo.priority(task.priority),
              onChanged: (done) => ref
                  .read(tasksRepositoryProvider)
                  .setDone(task.id, done: done),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(task.title, style: titleStyle),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Wrap(spacing: 10, runSpacing: 2, children: meta),
                    ),
                ],
              ),
            ),
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 4),
                child: Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: nemo.priority(task.priority),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round animated checkbox; the ring takes the priority colour.
class DoneCheck extends StatelessWidget {
  const DoneCheck({
    required this.done,
    required this.onChanged,
    this.color,
    super.key,
  });

  final bool done;
  final Color? color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = color ?? scheme.outline;
    return Semantics(
      checked: done,
      button: true,
      child: InkResponse(
        onTap: () => onChanged(!done),
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? scheme.primary : Colors.transparent,
              border: Border.all(color: done ? scheme.primary : ring, width: 2),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }
}
