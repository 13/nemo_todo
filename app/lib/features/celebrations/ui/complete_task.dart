import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

/// What ticking a task did: the message the completion earned, null when
/// it earned none (an untick, an unlock, celebrations off), and the next
/// occurrence of a repeating task it put on the list, which an Undo takes
/// back.
typedef TaskCompletion = ({CelebrationCheer? cheer, String? spawned});

/// Ticks [task] on or off because a person tapped it, and celebrates a
/// completion.
///
/// With [showPill] false the caller shows the completion's message itself
/// instead of the floating pill.
///
/// Both providers are read before the write: a ticked task can leave the
/// screen it was on, and a `ref` is not to be used once its widget is gone.
Future<TaskCompletion> completeTask(
  WidgetRef ref,
  Task task, {
  required bool done,
  bool showPill = true,
}) => completeTaskWith(
  ref.read(tasksRepositoryProvider),
  ref.read(celebrationControllerProvider),
  task,
  done: done,
  showPill: showPill,
);

/// [completeTask] with its providers already read, for a caller that
/// writes other tasks first, by which time its widget, and so its `ref`,
/// may be gone.
Future<TaskCompletion> completeTaskWith(
  TasksRepository tasks,
  CelebrationController celebrations,
  Task task, {
  required bool done,
  bool showPill = true,
}) async {
  if (!done) {
    await tasks.setDone(task.id, done: false);
    return (cheer: null, spawned: null);
  }
  String? spawned;
  // The write runs in the controller's turn, so it may wait briefly behind
  // a backfill already queued.
  final event = await celebrations.onCompleted(
    task,
    write: () async => spawned = await tasks.setDone(task.id, done: true),
    showPill: showPill,
  );
  final cheer = switch (event) {
    TickCelebration(:final cheer) => cheer,
    DayClearedCelebration(:final cheer) => cheer,
    _ => null,
  };
  return (cheer: cheer, spawned: spawned);
}
