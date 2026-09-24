import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_detail_sections.dart';
import 'package:nemo/features/tasks/ui/task_work_section.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Everything about one task. Edits save as you go.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({
    required this.taskId,
    this.embedded = false,
    super.key,
  });

  final String taskId;

  /// True in the pane beside a list on a wide window. There is no page to
  /// go back to there, so nothing offers to.
  final bool embedded;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _titleFocus = FocusNode();
  final _notesFocus = FocusNode();
  Timer? _debounce;
  Task? _task;

  @override
  void dispose() {
    _debounce?.cancel();
    _flushText();
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  /// Keeps controllers in step with the stored task unless being edited.
  void _adopt(Task task) {
    _task = task;
    if (!_titleFocus.hasFocus && _title.text != task.title) {
      _title.text = task.title;
    }
    if (!_notesFocus.hasFocus && _notes.text != task.notes) {
      _notes.text = task.notes;
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _flushText);
  }

  void _flushText() {
    final task = _task;
    if (task == null) return;
    final title = _title.text.trim();
    final notes = _notes.text;
    if ((title.isEmpty || title == task.title) && notes == task.notes) return;
    unawaited(
      _save(
        task.copyWith(title: title.isEmpty ? task.title : title, notes: notes),
      ),
    );
  }

  Future<void> _save(Task task) {
    _task = task;
    return ref.read(tasksRepositoryProvider).save(task);
  }

  Future<void> _delete(Task task) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.commonDelete),
        content: Text(l.tasksDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-task'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(tasksRepositoryProvider);
    await repo.delete(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
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
    if (widget.embedded) {
      ref.read(selectedTaskProvider.notifier).select(null);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final task = ref.watch(taskByIdProvider(widget.taskId)).value;
    if (task == null) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
        body: Center(child: Text(l.tasksNotFound)),
      );
    }
    _adopt(task);
    final nemo = context.nemoColors;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        actions: [
          IconButton(
            key: const Key('task-delete'),
            tooltip: l.commonDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(task),
          ),
        ],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DoneCheck(
                    done: task.done,
                    color: nemo.priority(task.priority),
                    onChanged: (done) => completeTask(ref, task, done: done),
                    celebrate: ref.watch(celebrationsEnabledProvider),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('task-title'),
                    controller: _title,
                    focusNode: _titleFocus,
                    onChanged: (_) => _onTextChanged(),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                    decoration: InputDecoration(
                      hintText: l.tasksTitleHint,
                      filled: false,
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              key: const Key('task-notes'),
              controller: _notes,
              focusNode: _notesFocus,
              onChanged: (_) => _onTextChanged(),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l.tasksNotesHint,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 20),
            DetailLabel(l.tasksPhotos),
            PhotoStrip(parentKind: PhotoParent.task, parentId: task.id),
            const SizedBox(height: 20),
            TaskDueSection(task: task, save: _save),
            const SizedBox(height: 8),
            TaskRepeatSection(task: task, save: _save),
            const SizedBox(height: 20),
            TaskPrioritySection(task: task, save: _save),
            const SizedBox(height: 20),
            TaskWorkSection(task: task, save: _save),
            const SizedBox(height: 20),
            TaskListSection(task: task, save: _save),
            const SizedBox(height: 20),
            TaskTagsSection(task: task, save: _save),
            const SizedBox(height: 20),
            SubtasksSection(taskId: task.id),
          ],
        ),
      ),
    );
  }
}
