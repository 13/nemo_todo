// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The tasks picked while selecting several at once.
///
/// Null when not selecting. An empty set means selecting with nothing
/// picked yet, which is different: the selection bar stays up until the
/// user ends it.

@ProviderFor(TaskSelection)
final taskSelectionProvider = TaskSelectionProvider._();

/// The tasks picked while selecting several at once.
///
/// Null when not selecting. An empty set means selecting with nothing
/// picked yet, which is different: the selection bar stays up until the
/// user ends it.
final class TaskSelectionProvider
    extends $NotifierProvider<TaskSelection, Set<String>?> {
  /// The tasks picked while selecting several at once.
  ///
  /// Null when not selecting. An empty set means selecting with nothing
  /// picked yet, which is different: the selection bar stays up until the
  /// user ends it.
  TaskSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSelectionHash();

  @$internal
  @override
  TaskSelection create() => TaskSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>?>(value),
    );
  }
}

String _$taskSelectionHash() => r'e7c92025a5e0088c615fe058c20d4cdf8711f3c5';

/// The tasks picked while selecting several at once.
///
/// Null when not selecting. An empty set means selecting with nothing
/// picked yet, which is different: the selection bar stays up until the
/// user ends it.

abstract class _$TaskSelection extends $Notifier<Set<String>?> {
  Set<String>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>?, Set<String>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>?, Set<String>?>,
              Set<String>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
