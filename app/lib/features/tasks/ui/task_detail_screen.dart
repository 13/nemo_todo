import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Everything about one task. Edits save as you go.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _tag = TextEditingController();
  final _subtask = TextEditingController();
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
    _tag.dispose();
    _subtask.dispose();
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

  Future<void> _pickDate(Task task) async {
    final now = ref.read(nowProvider)();
    final current = task.dueAt == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    final dueAt = task.dueHasTime
        ? composeDue(picked, hour: current.hour, minute: current.minute)
        : dayStartMs(picked);
    await _save(task.copyWith(dueAt: dueAt));
  }

  Future<void> _pickTime(Task task) async {
    final current = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    final picked = await showTimePicker(
      context: context,
      initialTime: task.dueHasTime
          ? TimeOfDay(hour: current.hour, minute: current.minute)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    await _save(
      task.copyWith(
        dueAt: composeDue(current, hour: picked.hour, minute: picked.minute),
        dueHasTime: true,
      ),
    );
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
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () => repo.restore(task.id),
        ),
      ),
    );
    if (context.canPop()) {
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
        appBar: AppBar(),
        body: Center(child: Text(l.tasksNotFound)),
      );
    }
    _adopt(task);
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final lists = ref.watch(allListsProvider).value ?? const [];
    final subtasks =
        ref.watch(subtasksByTaskProvider(task.id)).value ?? const [];
    final remindersSupported = ref.watch(remindersSupportedProvider);
    final dueAt = task.dueAt;

    return Scaffold(
      appBar: AppBar(
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
                    onChanged: (done) => ref
                        .read(tasksRepositoryProvider)
                        .setDone(task.id, done: done),
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
            _Label(l.tasksDue),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  key: const Key('task-date'),
                  avatar: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    dueAt == null
                        ? l.tasksNoDue
                        : dueLabel(
                            l,
                            locale,
                            dueAt: dueAt,
                            hasTime: false,
                            now: now,
                          ),
                  ),
                  onPressed: () => _pickDate(task),
                ),
                if (dueAt != null)
                  ActionChip(
                    key: const Key('task-time'),
                    avatar: const Icon(Icons.access_time_rounded, size: 18),
                    label: Text(
                      task.dueHasTime
                          ? timeLabel(locale, dueAt)
                          : l.tasksNoTime,
                    ),
                    onPressed: () => _pickTime(task),
                  ),
                if (dueAt != null)
                  ActionChip(
                    key: const Key('task-clear-date'),
                    avatar: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l.tasksClearDue),
                    onPressed: () => _save(
                      task.copyWith(
                        dueAt: null,
                        dueHasTime: false,
                        remind: false,
                      ),
                    ),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('task-remind'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(l.tasksRemind),
              subtitle: remindersSupported
                  ? null
                  : Text(l.tasksRemindUnavailable),
              value: task.remind && dueAt != null,
              onChanged: dueAt == null || !remindersSupported
                  ? null
                  : (value) async {
                      if (value &&
                          !await ref
                              .read(reminderSchedulerProvider)
                              .ensurePermission()) {
                        return;
                      }
                      await _save(task.copyWith(remind: value));
                    },
            ),
            const SizedBox(height: 8),
            _Label(l.tasksPriority),
            // Chips rather than a segmented button: four labels with flags
            // do not fit across a phone, and a wrapped label reads badly.
            Wrap(
              key: const Key('task-priority'),
              spacing: 8,
              children: [
                for (final (value, label) in [
                  (0, l.priorityNone),
                  (1, l.priorityLow),
                  (2, l.priorityMedium),
                  (3, l.priorityHigh),
                ])
                  ChoiceChip(
                    key: Key('priority-$value'),
                    selected: task.priority == value,
                    showCheckmark: false,
                    avatar: value == 0
                        ? null
                        : Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: nemo.priority(value),
                          ),
                    label: Text(label),
                    onSelected: (_) => _save(task.copyWith(priority: value)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _Label(l.tasksList),
            DropdownMenu<String>(
              // Rebuilt when the lists arrive: a DropdownMenu resolves
              // `initialSelection` against the entries it was created with,
              // and the first build happens before the stream has emitted.
              key: Key('task-list-${lists.length}-${task.listId}'),
              initialSelection: task.listId,
              expandedInsets: EdgeInsets.zero,
              leadingIcon: Icon(
                listIcon(
                  lists.where((x) => x.id == task.listId).firstOrNull?.icon ??
                      'list',
                ),
              ),
              dropdownMenuEntries: [
                for (final x in lists)
                  DropdownMenuEntry(
                    value: x.id,
                    label: x.isInbox ? l.listsInbox : x.name,
                    leadingIcon: Icon(
                      listIcon(x.icon),
                      color: nemo.listColor(x.color),
                    ),
                  ),
              ],
              onSelected: (id) {
                if (id != null && id != task.listId) {
                  unawaited(_save(task.copyWith(listId: id)));
                }
              },
            ),
            const SizedBox(height: 20),
            _Label(l.tasksTags),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in task.tags)
                  InputChip(
                    key: Key('tag-$tag'),
                    label: Text(tag),
                    onDeleted: () => _save(
                      task.copyWith(
                        tags: task.tags.where((t) => t != tag).toList(),
                      ),
                    ),
                  ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    key: const Key('task-tag-field'),
                    controller: _tag,
                    decoration: InputDecoration(
                      hintText: l.tasksTagsHint,
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      final tag = value
                          .trim()
                          .replaceAll(RegExp(r'\s+'), '-')
                          .toLowerCase();
                      _tag.clear();
                      if (tag.isEmpty || task.tags.contains(tag)) return;
                      unawaited(
                        _save(task.copyWith(tags: [...task.tags, tag])),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Label(l.tasksSubtasks),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                if (newIndex == oldIndex) return;
                final moved = subtasks[oldIndex];
                final rest = [...subtasks]..removeAt(oldIndex);
                unawaited(
                  ref
                      .read(subtasksRepositoryProvider)
                      .placeBetween(
                        moved.id,
                        before: newIndex > 0 ? rest[newIndex - 1].id : null,
                        after: newIndex < rest.length
                            ? rest[newIndex].id
                            : null,
                      ),
                );
              },
              children: [
                for (var i = 0; i < subtasks.length; i++)
                  ListTile(
                    key: ValueKey('subtask-${subtasks[i].id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: subtasks[i].done,
                      onChanged: (v) => ref
                          .read(subtasksRepositoryProvider)
                          .save(subtasks[i].copyWith(done: v ?? false)),
                    ),
                    title: Text(
                      subtasks[i].title,
                      style: TextStyle(
                        decoration: subtasks[i].done
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtasks[i].done
                            ? scheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l.commonDelete,
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => ref
                              .read(subtasksRepositoryProvider)
                              .delete(subtasks[i].id),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle_rounded),
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
                prefixIcon: const Icon(Icons.add_rounded),
              ),
              onSubmitted: (value) async {
                if (value.trim().isEmpty) return;
                _subtask.clear();
                await ref.read(subtasksRepositoryProvider).add(task.id, value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
