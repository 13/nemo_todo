import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/features/tasks/ui/bulk_actions.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/screens/shell_screen.dart';
import 'package:nemo_core/nemo_core.dart';

/// The bar shown while several tasks are picked: how many, and what can be
/// done to them all at once.
///
/// It acts on the picked tasks the screen lists, in the order it lists
/// them; a pick that has left the screen is not acted on.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  /// Whether the bar takes the top of the screen, as on a wide window, or
  /// the foot of it, within a thumb's reach, as on a phone.
  static bool onTop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ShellScreen.splitBreakpoint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(taskSelectionProvider) ?? const <String>{};
    return _VisibleTasks(
      builder: (context, visible) {
        final tasks = [
          for (final task in visible)
            if (picked.contains(task.id)) task,
        ];
        return _bar(context, ref, tasks);
      },
    );
  }

  Widget _bar(BuildContext context, WidgetRef ref, List<Task> tasks) {
    final l = L.of(context);
    final none = tasks.isEmpty;
    final reopen = !none && tasks.every((t) => t.done);
    final cancel = IconButton(
      key: const Key('selection-cancel'),
      tooltip: l.commonCancel,
      onPressed: () => ref.read(taskSelectionProvider.notifier).end(),
      icon: const AppIcon(Icons.close_rounded),
    );
    // Announced as it changes, so a screen reader hears each pick land.
    final count = Semantics(
      liveRegion: true,
      child: Text(l.selectionCount(tasks.length)),
    );
    final actions = [
      IconButton(
        key: const Key('selection-done'),
        tooltip: reopen ? l.taskMenuUndone : l.taskMenuDone,
        onPressed: none ? null : () => completeTasks(context, ref, tasks),
        icon: AppIcon(reopen ? Icons.undo_rounded : Icons.check_rounded),
      ),
      IconButton(
        key: const Key('selection-move'),
        tooltip: l.taskMenuMove,
        onPressed: none ? null : () => rescheduleTasks(context, ref, tasks),
        icon: const AppIcon(Icons.event_rounded),
      ),
      IconButton(
        key: const Key('selection-delete'),
        tooltip: l.commonDelete,
        onPressed: none ? null : () => deleteTasksWithUndo(context, ref, tasks),
        icon: const AppIcon(Icons.delete_outline_rounded),
      ),
    ];

    // At the top it is a top bar, in each style's own look.
    if (onTop(context)) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: cancel,
        title: count,
        actions: actions,
      );
    }
    final row = Row(
      children: [
        cancel,
        const SizedBox(width: 8),
        Expanded(child: count),
        ...actions,
      ],
    );
    if (context.appStyle == AppStyle.material) {
      return BottomAppBar(child: row);
    }
    // At the foot, nemo's and macOS's quick-add bar is what it stands in
    // for, so it draws the same way: raised in nemo, flat under a hairline
    // on macOS.
    final flat = context.appStyle == AppStyle.macos;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: flat ? 0 : 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: flat
          ? Border(
              top: BorderSide(color: context.nemoColors.separator, width: 0.5),
            )
          : null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: row,
        ),
      ),
    );
  }
}

/// Builds with the tasks the screen lists, again whenever they change.
///
/// The list publishes them while it builds, and a widget elsewhere in the
/// tree cannot be rebuilt in the middle of that; a change heard then waits
/// for the frame to finish.
class _VisibleTasks extends ConsumerStatefulWidget {
  const _VisibleTasks({required this.builder});

  final Widget Function(BuildContext context, List<Task> visible) builder;

  @override
  ConsumerState<_VisibleTasks> createState() => _VisibleTasksState();
}

class _VisibleTasksState extends ConsumerState<_VisibleTasks> {
  late final ValueNotifier<List<Task>> _visible = ref.read(
    visibleTasksProvider,
  );

  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _visible.addListener(_changed);
  }

  @override
  void dispose() {
    _visible.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible.value);
}

/// The top bar's button that starts picking several tasks at once.
class SelectTasksButton extends ConsumerWidget {
  const SelectTasksButton({this.offered = true, super.key});

  /// Whether there is anything to pick: without it the button takes no
  /// room, though it stays among the bar's actions, which is how the
  /// screen's scaffold knows the screen picks tasks at all.
  final bool offered;

  @override
  Widget build(BuildContext context, WidgetRef ref) => !offered
      ? const SizedBox.shrink()
      : IconButton(
          key: const Key('select-tasks'),
          tooltip: L.of(context).selectTasks,
          onPressed: () => ref.read(taskSelectionProvider.notifier).start(),
          icon: const AppIcon(Icons.checklist_rounded),
        );
}
