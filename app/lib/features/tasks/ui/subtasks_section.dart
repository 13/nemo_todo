import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/features/tasks/ui/task_detail_sections.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The task's subtasks: tick, delete, drag into order, add another.
class SubtasksSection extends ConsumerStatefulWidget {
  const SubtasksSection({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends ConsumerState<SubtasksSection> {
  final _subtask = TextEditingController();

  @override
  void dispose() {
    _subtask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(subtasksRepositoryProvider);
    final subtasks =
        ref.watch(subtasksByTaskProvider(widget.taskId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksSubtasks),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            if (newIndex == oldIndex) return;
            final moved = subtasks[oldIndex];
            final rest = [...subtasks]..removeAt(oldIndex);
            unawaited(
              repo.placeBetween(
                moved.id,
                before: newIndex > 0 ? rest[newIndex - 1].id : null,
                after: newIndex < rest.length ? rest[newIndex].id : null,
              ),
            );
          },
          children: [
            for (var i = 0; i < subtasks.length; i++)
              ListTile(
                key: ValueKey('subtask-${subtasks[i].id}'),
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  semanticLabel: subtasks[i].title,
                  value: subtasks[i].done,
                  onChanged: (v) =>
                      repo.save(subtasks[i].copyWith(done: v ?? false)),
                ),
                title: Text(
                  subtasks[i].title,
                  style: TextStyle(
                    decoration: subtasks[i].done
                        ? TextDecoration.lineThrough
                        : null,
                    color: subtasks[i].done ? scheme.onSurfaceVariant : null,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l.commonDelete,
                      icon: const AppIcon(Icons.close_rounded, size: 20),
                      onPressed: () => repo.delete(subtasks[i].id),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const AppIcon(Icons.drag_handle_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
        TextField(
          key: const Key('task-subtask-field'),
          controller: _subtask,
          decoration: InputDecoration(
            hintText: l.tasksSubtaskHint,
            prefixIcon: const AppIcon(Icons.add_rounded),
          ),
          onSubmitted: (value) async {
            if (value.trim().isEmpty) return;
            _subtask.clear();
            await repo.add(widget.taskId, value);
          },
        ),
      ],
    );
  }
}
