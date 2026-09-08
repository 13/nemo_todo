// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_task.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The task shown in the pane beside the list on a wide window.
///
/// Null on a phone, where a task is a page of its own and the back button
/// is how you leave it.

@ProviderFor(SelectedTask)
final selectedTaskProvider = SelectedTaskProvider._();

/// The task shown in the pane beside the list on a wide window.
///
/// Null on a phone, where a task is a page of its own and the back button
/// is how you leave it.
final class SelectedTaskProvider
    extends $NotifierProvider<SelectedTask, String?> {
  /// The task shown in the pane beside the list on a wide window.
  ///
  /// Null on a phone, where a task is a page of its own and the back button
  /// is how you leave it.
  SelectedTaskProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTaskProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTaskHash();

  @$internal
  @override
  SelectedTask create() => SelectedTask();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedTaskHash() => r'6f43ccf95c586958c715e667cac3c2516bcd6e71';

/// The task shown in the pane beside the list on a wide window.
///
/// Null on a phone, where a task is a page of its own and the back button
/// is how you leave it.

abstract class _$SelectedTask extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
