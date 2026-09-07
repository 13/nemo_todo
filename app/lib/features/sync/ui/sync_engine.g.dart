// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives synchronisation with the server.
///
/// One run at a time: a request arriving mid-run sets a flag and the loop
/// goes round again, so a burst of edits costs one round trip. Everything
/// the server sends is applied with the same last-write-wins rule the
/// server used, so both sides converge.

@ProviderFor(SyncEngine)
final syncEngineProvider = SyncEngineProvider._();

/// Drives synchronisation with the server.
///
/// One run at a time: a request arriving mid-run sets a flag and the loop
/// goes round again, so a burst of edits costs one round trip. Everything
/// the server sends is applied with the same last-write-wins rule the
/// server used, so both sides converge.
final class SyncEngineProvider
    extends $NotifierProvider<SyncEngine, SyncState> {
  /// Drives synchronisation with the server.
  ///
  /// One run at a time: a request arriving mid-run sets a flag and the loop
  /// goes round again, so a burst of edits costs one round trip. Everything
  /// the server sends is applied with the same last-write-wins rule the
  /// server used, so both sides converge.
  SyncEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncEngineProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncEngineHash();

  @$internal
  @override
  SyncEngine create() => SyncEngine();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncState>(value),
    );
  }
}

String _$syncEngineHash() => r'3181112a05e292cb1f580af14999499c20e2a1df';

/// Drives synchronisation with the server.
///
/// One run at a time: a request arriving mid-run sets a flag and the loop
/// goes round again, so a burst of edits costs one round trip. Everything
/// the server sends is applied with the same last-write-wins rule the
/// server used, so both sides converge.

abstract class _$SyncEngine extends $Notifier<SyncState> {
  SyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SyncState, SyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncState, SyncState>,
              SyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Number of local changes waiting to reach the server.

@ProviderFor(pendingChanges)
final pendingChangesProvider = PendingChangesProvider._();

/// Number of local changes waiting to reach the server.

final class PendingChangesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Number of local changes waiting to reach the server.
  PendingChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingChangesHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return pendingChanges(ref);
  }
}

String _$pendingChangesHash() => r'1d0664c527809fc7820b003744735b12400abae6';
