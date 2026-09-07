import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tasks_providers.g.dart';

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => TasksRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    now: ref.watch(nowProvider),
  ),
);

final subtasksRepositoryProvider = Provider<SubtasksRepository>(
  (ref) => SubtasksRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

@riverpod
Stream<List<Task>> tasksByList(Ref ref, String listId) =>
    ref.watch(tasksRepositoryProvider).watchByList(listId);

@riverpod
Stream<Task?> taskById(Ref ref, String id) =>
    ref.watch(tasksRepositoryProvider).watch(id);

@riverpod
Stream<List<Task>> todayTasks(Ref ref) =>
    ref.watch(tasksRepositoryProvider).watchToday(ref.watch(nowProvider)());

@riverpod
Stream<List<Task>> upcomingTasks(Ref ref) =>
    ref.watch(tasksRepositoryProvider).watchUpcoming(ref.watch(nowProvider)());

@riverpod
Stream<List<Task>> searchTasks(Ref ref, String query) =>
    ref.watch(tasksRepositoryProvider).search(query);

@riverpod
Stream<int> openTaskCount(Ref ref, String listId) =>
    ref.watch(tasksRepositoryProvider).watchOpenCount(listId);

@riverpod
Stream<List<Subtask>> subtasksByTask(Ref ref, String taskId) =>
    ref.watch(subtasksRepositoryProvider).watchByTask(taskId);

@riverpod
Stream<Map<String, ({int done, int total})>> subtaskProgress(Ref ref) =>
    ref.watch(subtasksRepositoryProvider).watchProgress();
