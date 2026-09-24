import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

/// Ticks [task] on or off because a person tapped it, and celebrates a
/// completion.
///
/// Returns the message the completion earned, null when it earned none
/// (an untick, an unlock, celebrations off). With [showPill] false the
/// caller shows that message itself instead of the floating pill.
///
/// Both providers are read before the write: a ticked task can leave the
/// screen it was on, and a `ref` is not to be used once its widget is gone.
Future<CelebrationCheer?> completeTask(
  WidgetRef ref,
  Task task, {
  required bool done,
  bool showPill = true,
}) async {
  final tasks = ref.read(tasksRepositoryProvider);
  final celebrations = ref.read(celebrationControllerProvider);
  if (!done) {
    await tasks.setDone(task.id, done: false);
    return null;
  }
  // The write runs in the controller's turn, so it may wait briefly behind
  // a backfill already queued.
  final event = await celebrations.onCompleted(
    task,
    write: () => tasks.setDone(task.id, done: true),
    showPill: showPill,
  );
  return switch (event) {
    TickCelebration(:final cheer) => cheer,
    DayClearedCelebration(:final cheer) => cheer,
    _ => null,
  };
}
