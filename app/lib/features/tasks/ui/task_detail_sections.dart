import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/tasks/ui/custom_repeat_dialog.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Saves an edited copy of the task on screen.
typedef TaskSaver = Future<void> Function(Task task);

/// The small heading above each part of the task detail screen.
class DetailLabel extends StatelessWidget {
  const DetailLabel(this.text, {super.key});

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

/// The due date, its time, and whether to be reminded.
class TaskDueSection extends ConsumerWidget {
  const TaskDueSection({required this.task, required this.save, super.key});

  final Task task;
  final TaskSaver save;

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
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
    await save(task.copyWith(dueAt: dueAt));
  }

  Future<void> _pickTime(BuildContext context) async {
    final current = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    final picked = await showTimePicker(
      context: context,
      initialTime: task.dueHasTime
          ? TimeOfDay(hour: current.hour, minute: current.minute)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    await save(
      task.copyWith(
        dueAt: composeDue(current, hour: picked.hour, minute: picked.minute),
        dueHasTime: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final remindersSupported = ref.watch(remindersSupportedProvider);
    final dueAt = task.dueAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksDue),
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
              onPressed: () => _pickDate(context, ref),
            ),
            if (dueAt != null)
              ActionChip(
                key: const Key('task-time'),
                avatar: const Icon(Icons.access_time_rounded, size: 18),
                label: Text(
                  task.dueHasTime ? timeLabel(locale, dueAt) : l.tasksNoTime,
                ),
                onPressed: () => _pickTime(context),
              ),
            if (dueAt != null)
              ActionChip(
                key: const Key('task-clear-date'),
                avatar: const Icon(Icons.close_rounded, size: 18),
                label: Text(l.tasksClearDue),
                onPressed: () => save(
                  task.copyWith(dueAt: null, dueHasTime: false, remind: false),
                ),
              ),
          ],
        ),
        SwitchListTile(
          key: const Key('task-remind'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(l.tasksRemind),
          subtitle: remindersSupported ? null : Text(l.tasksRemindUnavailable),
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
                  await save(task.copyWith(remind: value));
                },
        ),
      ],
    );
  }
}

/// How often the task comes back.
class TaskRepeatSection extends StatelessWidget {
  const TaskRepeatSection({required this.task, required this.save, super.key});

  final Task task;
  final TaskSaver save;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueAt = task.dueAt;
    final choices = _repeatChoices(l, locale, dueAt);
    final rule = task.repeatRule;
    // A rule the chips do not name -- every three days, the second
    // Tuesday -- is shown on the custom chip rather than on none of them.
    final custom = rule != null && choices.every((c) => c.$1 != rule);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksRepeat),
        // Same chips as the priority row below, for the same reason: the
        // labels do not fit across a phone in one segmented row.
        Wrap(
          key: const Key('task-repeat'),
          spacing: 8,
          children: [
            for (final (choice, label) in choices)
              ChoiceChip(
                key: Key(_repeatKey(choice)),
                selected: rule == choice,
                showCheckmark: false,
                avatar: choice == null
                    ? null
                    : const Icon(Icons.repeat_rounded, size: 18),
                label: Text(label),
                // A rule with no date to count from would never come back,
                // so the row waits for one.
                onSelected: dueAt == null
                    ? null
                    : (_) => save(task.copyWith(repeat: choice?.encode())),
              ),
            ChoiceChip(
              key: const Key('repeat-custom'),
              selected: custom,
              showCheckmark: false,
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                custom ? describeRepeat(l, locale, rule) : l.repeatCustom,
              ),
              onSelected: dueAt == null
                  ? null
                  : (_) async {
                      final picked = await showCustomRepeatDialog(
                        context,
                        due: DateTime.fromMillisecondsSinceEpoch(dueAt),
                        initial: rule,
                      );
                      if (picked != null) {
                        await save(task.copyWith(repeat: picked.encode()));
                      }
                    },
            ),
            // A rule this version cannot read -- written by a newer app, or
            // by hand -- is shown as it stands rather than as no rule at
            // all, which would say the task does not repeat.
            if (task.repeat != null && task.repeatRule == null)
              ChoiceChip(
                key: const Key('repeat-unreadable'),
                selected: true,
                showCheckmark: false,
                avatar: const Icon(Icons.repeat_rounded, size: 18),
                label: Text(task.repeat!),
              ),
          ],
        ),
        if (dueAt == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.tasksRepeatNeedsDue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The four priorities, as chips.
class TaskPrioritySection extends StatelessWidget {
  const TaskPrioritySection({
    required this.task,
    required this.save,
    super.key,
  });

  final Task task;
  final TaskSaver save;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksPriority),
        // Chips rather than a segmented button: four labels with flags do
        // not fit across a phone, and a wrapped label reads badly.
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
                onSelected: (_) => save(task.copyWith(priority: value)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Which list the task is on.
class TaskListSection extends ConsumerWidget {
  const TaskListSection({required this.task, required this.save, super.key});

  final Task task;
  final TaskSaver save;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    final lists = ref.watch(allListsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksList),
        DropdownMenu<String>(
          // Rebuilt when the lists arrive: a DropdownMenu resolves
          // `initialSelection` against the entries it was created with, and
          // the first build happens before the stream has emitted.
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
              unawaited(save(task.copyWith(listId: id)));
            }
          },
        ),
      ],
    );
  }
}

/// The task's tags, and a field for another.
class TaskTagsSection extends StatefulWidget {
  const TaskTagsSection({required this.task, required this.save, super.key});

  final Task task;
  final TaskSaver save;

  @override
  State<TaskTagsSection> createState() => _TaskTagsSectionState();
}

class _TaskTagsSectionState extends State<TaskTagsSection> {
  final _tag = TextEditingController();

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final task = widget.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksTags),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in task.tags)
              InputChip(
                key: Key('tag-$tag'),
                label: Text(tag),
                onDeleted: () => widget.save(
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
                    widget.save(task.copyWith(tags: [...task.tags, tag])),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => repo.delete(subtasks[i].id),
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
            await repo.add(widget.taskId, value);
          },
        ),
      ],
    );
  }
}

/// The rules the picker offers, in the order they read.
///
/// "The last Friday of the month" only makes sense once there is a date to
/// take the weekday from, so it follows the due date rather than being
/// offered as a fixed choice.
List<(Repeat?, String)> _repeatChoices(L l, String locale, int? dueAt) {
  final due = dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt);
  return [
    (null, l.repeatNever),
    (Repeats.daily, l.repeatDaily),
    (Repeats.weekdays, l.repeatWeekdays),
    (Repeats.weekly, l.repeatWeekly),
    (Repeats.fortnightly, l.repeatFortnightly),
    (Repeats.monthly, l.repeatMonthly),
    if (due != null)
      (
        NthWeekdayRepeat(ordinal: NthWeekdayRepeat.last, weekday: due.weekday),
        l.repeatLastWeekday(weekdayName(locale, due)),
      ),
    (Repeats.yearly, l.repeatYearly),
  ];
}

/// A widget key that survives the rule's text: `every:2w` is not a key.
String _repeatKey(Repeat? rule) =>
    'repeat-${rule?.encode().replaceAll(RegExp('[^a-z0-9]+'), '-') ?? 'never'}';
