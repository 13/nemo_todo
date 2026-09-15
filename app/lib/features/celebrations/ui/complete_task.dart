import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

/// Ticks [task] on or off because a person tapped it, and celebrates a
/// completion.
///
/// Both providers are read before the write: a ticked task can leave the
/// screen it was on, and a `ref` is not to be used once its widget is gone.
Future<void> completeTask(
  WidgetRef ref,
  Task task, {
  required bool done,
}) async {
  final tasks = ref.read(tasksRepositoryProvider);
  final celebrations = ref.read(celebrationControllerProvider);
  if (!done) {
    await tasks.setDone(task.id, done: false);
    return;
  }
  await celebrations.onCompleted(
    task,
    write: () => tasks.setDone(task.id, done: true),
  );
}
