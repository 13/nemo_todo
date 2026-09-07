import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

class TaskSection {
  const TaskSection({required this.title, required this.tasks, this.color});

  final String title;
  final List<Task> tasks;
  final Color? color;
}

/// Sections of task tiles with swipe-to-complete, swipe-to-delete and
/// (for a single open section) long-press reordering. Completed tasks are
/// folded into a collapsible section.
class TaskListView extends ConsumerStatefulWidget {
  const TaskListView({
    required this.sections,
    this.completed = const [],
    this.showList = false,
    this.reorderable = false,
    this.header,
    super.key,
  });

  final List<TaskSection> sections;
  final List<Task> completed;
  final bool showList;
  final bool reorderable;
  final Widget? header;

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  var _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final slivers = <Widget>[
      if (widget.header != null) SliverToBoxAdapter(child: widget.header),
    ];
    for (final section in widget.sections) {
      if (section.tasks.isEmpty) continue;
      slivers
        ..add(
          SliverToBoxAdapter(
            child: SectionHeader(
              title: section.title,
              count: section.tasks.length,
              color: section.color,
            ),
          ),
        )
        ..add(
          widget.reorderable && widget.sections.length == 1
              ? _reorderable(section.tasks)
              : _plain(section.tasks),
        );
    }
    if (widget.completed.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: SectionHeader(
            title: l.tasksCompleted(widget.completed.length),
            collapsed: !_showCompleted,
            onToggle: () => setState(() => _showCompleted = !_showCompleted),
          ),
        ),
      );
      if (_showCompleted) slivers.add(_plain(widget.completed));
    }
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 24)));
    return CustomScrollView(slivers: slivers);
  }

  Widget _plain(List<Task> tasks) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    sliver: SliverList.builder(
      itemCount: tasks.length,
      itemBuilder: (context, i) => _dismissible(
        tasks[i],
        TaskTile(task: tasks[i], showList: widget.showList),
      ),
    ),
  );

  Widget _reorderable(List<Task> tasks) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    sliver: SliverReorderableList(
      itemCount: tasks.length,
      onReorderItem: (oldIndex, newIndex) =>
          _reorder(tasks, oldIndex, newIndex),
      itemBuilder: (context, i) => _dismissible(
        tasks[i],
        ReorderableDelayedDragStartListener(
          index: i,
          child: TaskTile(task: tasks[i], showList: widget.showList),
        ),
      ),
    ),
  );

  /// [newIndex] is already adjusted for the removed item.
  Future<void> _reorder(List<Task> tasks, int oldIndex, int newIndex) async {
    if (newIndex == oldIndex) return;
    final moved = tasks[oldIndex];
    final rest = [...tasks]..removeAt(oldIndex);
    final before = newIndex > 0 ? rest[newIndex - 1] : null;
    final after = newIndex < rest.length ? rest[newIndex] : null;
    await ref
        .read(tasksRepositoryProvider)
        .placeBetween(moved.id, before: before?.id, after: after?.id);
  }

  Widget _dismissible(Task task, Widget child) {
    final scheme = Theme.of(context).colorScheme;
    final l = L.of(context);
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      background: _swipeBackground(
        color: scheme.primaryContainer,
        icon: task.done ? Icons.undo_rounded : Icons.check_rounded,
        iconColor: scheme.onPrimaryContainer,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBackground(
        color: scheme.errorContainer,
        icon: Icons.delete_outline_rounded,
        iconColor: scheme.onErrorContainer,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        final repo = ref.read(tasksRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);
        if (direction == DismissDirection.startToEnd) {
          await repo.setDone(task.id, done: !task.done);
          if (!task.done) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(l.tasksCompletedSnack),
                action: SnackBarAction(
                  label: l.commonUndo,
                  onPressed: () => repo.setDone(task.id, done: false),
                ),
              ),
            );
          }
          // The row moves between sections on its own; no removal here.
          return false;
        }
        await repo.delete(task.id);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.tasksDeleted),
            action: SnackBarAction(
              label: l.commonUndo,
              onPressed: () => repo.restore(task.id),
            ),
          ),
        );
        return false;
      },
      child: child,
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required Alignment alignment,
  }) => Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Icon(icon, color: iconColor),
  );
}
