// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lists_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(allLists)
final allListsProvider = AllListsProvider._();

final class AllListsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TaskList>>,
          List<TaskList>,
          Stream<List<TaskList>>
        >
    with $FutureModifier<List<TaskList>>, $StreamProvider<List<TaskList>> {
  AllListsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allListsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allListsHash();

  @$internal
  @override
  $StreamProviderElement<List<TaskList>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TaskList>> create(Ref ref) {
    return allLists(ref);
  }
}

String _$allListsHash() => r'8684280ef9ac1cce21394176ebee0a612a8bcb09';

@ProviderFor(listById)
final listByIdProvider = ListByIdFamily._();

final class ListByIdProvider
    extends
        $FunctionalProvider<AsyncValue<TaskList?>, TaskList?, Stream<TaskList?>>
    with $FutureModifier<TaskList?>, $StreamProvider<TaskList?> {
  ListByIdProvider._({
    required ListByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'listByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$listByIdHash();

  @override
  String toString() {
    return r'listByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<TaskList?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<TaskList?> create(Ref ref) {
    final argument = this.argument as String;
    return listById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ListByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$listByIdHash() => r'e572856310c9d74565bb6a135950513fd3d64d43';

final class ListByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<TaskList?>, String> {
  ListByIdFamily._()
    : super(
        retry: null,
        name: r'listByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ListByIdProvider call(String id) =>
      ListByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'listByIdProvider';
}

/// Sharing metadata by list id, as last reported by the server.

@ProviderFor(listMeta)
final listMetaProvider = ListMetaProvider._();

/// Sharing metadata by list id, as last reported by the server.

final class ListMetaProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, ListSharing>>,
          Map<String, ListSharing>,
          Stream<Map<String, ListSharing>>
        >
    with
        $FutureModifier<Map<String, ListSharing>>,
        $StreamProvider<Map<String, ListSharing>> {
  /// Sharing metadata by list id, as last reported by the server.
  ListMetaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listMetaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listMetaHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, ListSharing>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, ListSharing>> create(Ref ref) {
    return listMeta(ref);
  }
}

String _$listMetaHash() => r'34e0dd74f62d50c9f0b967f2fb98da91d1d28469';
