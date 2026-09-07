// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tasksByList)
final tasksByListProvider = TasksByListFamily._();

final class TasksByListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  TasksByListProvider._({
    required TasksByListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tasksByListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tasksByListHash();

  @override
  String toString() {
    return r'tasksByListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    final argument = this.argument as String;
    return tasksByList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksByListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tasksByListHash() => r'27d3c67dc7ca6e382c6d312b8c9be5616a63ab97';

final class TasksByListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Task>>, String> {
  TasksByListFamily._()
    : super(
        retry: null,
        name: r'tasksByListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TasksByListProvider call(String listId) =>
      TasksByListProvider._(argument: listId, from: this);

  @override
  String toString() => r'tasksByListProvider';
}

@ProviderFor(taskById)
final taskByIdProvider = TaskByIdFamily._();

final class TaskByIdProvider
    extends $FunctionalProvider<AsyncValue<Task?>, Task?, Stream<Task?>>
    with $FutureModifier<Task?>, $StreamProvider<Task?> {
  TaskByIdProvider._({
    required TaskByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskByIdHash();

  @override
  String toString() {
    return r'taskByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Task?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Task?> create(Ref ref) {
    final argument = this.argument as String;
    return taskById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskByIdHash() => r'ae3c206958b941e8505c19ef611f022636669f5d';

final class TaskByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Task?>, String> {
  TaskByIdFamily._()
    : super(
        retry: null,
        name: r'taskByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskByIdProvider call(String id) =>
      TaskByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'taskByIdProvider';
}

@ProviderFor(todayTasks)
final todayTasksProvider = TodayTasksProvider._();

final class TodayTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  TodayTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'todayTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$todayTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return todayTasks(ref);
  }
}

String _$todayTasksHash() => r'db990ce5b77475bff2f19e128d9b81838b7a6970';

@ProviderFor(upcomingTasks)
final upcomingTasksProvider = UpcomingTasksProvider._();

final class UpcomingTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  UpcomingTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'upcomingTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$upcomingTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return upcomingTasks(ref);
  }
}

String _$upcomingTasksHash() => r'4edca54c676891ffcc4ea851d1260f592d2f696a';

@ProviderFor(searchTasks)
final searchTasksProvider = SearchTasksFamily._();

final class SearchTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  SearchTasksProvider._({
    required SearchTasksFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchTasksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchTasksHash();

  @override
  String toString() {
    return r'searchTasksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    final argument = this.argument as String;
    return searchTasks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchTasksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchTasksHash() => r'3a17fd74e77a69ec1b8a36f746e9234006fbb0fc';

final class SearchTasksFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Task>>, String> {
  SearchTasksFamily._()
    : super(
        retry: null,
        name: r'searchTasksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SearchTasksProvider call(String query) =>
      SearchTasksProvider._(argument: query, from: this);

  @override
  String toString() => r'searchTasksProvider';
}

@ProviderFor(openTaskCount)
final openTaskCountProvider = OpenTaskCountFamily._();

final class OpenTaskCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  OpenTaskCountProvider._({
    required OpenTaskCountFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'openTaskCountProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$openTaskCountHash();

  @override
  String toString() {
    return r'openTaskCountProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    final argument = this.argument as String;
    return openTaskCount(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OpenTaskCountProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$openTaskCountHash() => r'a9748df85d3402f60b20f92299360f1b7b0bb2c1';

final class OpenTaskCountFamily extends $Family
    with $FunctionalFamilyOverride<Stream<int>, String> {
  OpenTaskCountFamily._()
    : super(
        retry: null,
        name: r'openTaskCountProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  OpenTaskCountProvider call(String listId) =>
      OpenTaskCountProvider._(argument: listId, from: this);

  @override
  String toString() => r'openTaskCountProvider';
}

@ProviderFor(subtasksByTask)
final subtasksByTaskProvider = SubtasksByTaskFamily._();

final class SubtasksByTaskProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Subtask>>,
          List<Subtask>,
          Stream<List<Subtask>>
        >
    with $FutureModifier<List<Subtask>>, $StreamProvider<List<Subtask>> {
  SubtasksByTaskProvider._({
    required SubtasksByTaskFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'subtasksByTaskProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtasksByTaskHash();

  @override
  String toString() {
    return r'subtasksByTaskProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Subtask>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Subtask>> create(Ref ref) {
    final argument = this.argument as String;
    return subtasksByTask(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SubtasksByTaskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtasksByTaskHash() => r'5cadc01f407fea4021e4820ee500e5de24d69ad5';

final class SubtasksByTaskFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Subtask>>, String> {
  SubtasksByTaskFamily._()
    : super(
        retry: null,
        name: r'subtasksByTaskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubtasksByTaskProvider call(String taskId) =>
      SubtasksByTaskProvider._(argument: taskId, from: this);

  @override
  String toString() => r'subtasksByTaskProvider';
}

@ProviderFor(subtaskProgress)
final subtaskProgressProvider = SubtaskProgressProvider._();

final class SubtaskProgressProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ({int done, int total})>>,
          Map<String, ({int done, int total})>,
          Stream<Map<String, ({int done, int total})>>
        >
    with
        $FutureModifier<Map<String, ({int done, int total})>>,
        $StreamProvider<Map<String, ({int done, int total})>> {
  SubtaskProgressProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtaskProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtaskProgressHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, ({int done, int total})>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, ({int done, int total})>> create(Ref ref) {
    return subtaskProgress(ref);
  }
}

String _$subtaskProgressHash() => r'99cfa70cde278097a60a244f08fb4682f15268f8';
