// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(notesByList)
final notesByListProvider = NotesByListFamily._();

final class NotesByListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  NotesByListProvider._({
    required NotesByListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'notesByListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$notesByListHash();

  @override
  String toString() {
    return r'notesByListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    final argument = this.argument as String;
    return notesByList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NotesByListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$notesByListHash() => r'9ecb616d310bf013437fbf0ac0532959cc2641a3';

final class NotesByListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Note>>, String> {
  NotesByListFamily._()
    : super(
        retry: null,
        name: r'notesByListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NotesByListProvider call(String listId) =>
      NotesByListProvider._(argument: listId, from: this);

  @override
  String toString() => r'notesByListProvider';
}

@ProviderFor(allNotes)
final allNotesProvider = AllNotesProvider._();

final class AllNotesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  AllNotesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allNotesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allNotesHash();

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    return allNotes(ref);
  }
}

String _$allNotesHash() => r'13097cd417274d397adbab1246471f1e68a2fe95';

@ProviderFor(noteById)
final noteByIdProvider = NoteByIdFamily._();

final class NoteByIdProvider
    extends $FunctionalProvider<AsyncValue<Note?>, Note?, Stream<Note?>>
    with $FutureModifier<Note?>, $StreamProvider<Note?> {
  NoteByIdProvider._({
    required NoteByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteByIdHash();

  @override
  String toString() {
    return r'noteByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Note?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Note?> create(Ref ref) {
    final argument = this.argument as String;
    return noteById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteByIdHash() => r'953cac31aecf81685e7c69b3b5ebbbcb399ec5af';

final class NoteByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Note?>, String> {
  NoteByIdFamily._()
    : super(
        retry: null,
        name: r'noteByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteByIdProvider call(String id) =>
      NoteByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'noteByIdProvider';
}

@ProviderFor(noteSearch)
final noteSearchProvider = NoteSearchFamily._();

final class NoteSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Note>>,
          List<Note>,
          Stream<List<Note>>
        >
    with $FutureModifier<List<Note>>, $StreamProvider<List<Note>> {
  NoteSearchProvider._({
    required NoteSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteSearchHash();

  @override
  String toString() {
    return r'noteSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Note>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Note>> create(Ref ref) {
    final argument = this.argument as String;
    return noteSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteSearchHash() => r'56a395bffd5787c8d2b757fe0cd11129b17a7492';

final class NoteSearchFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Note>>, String> {
  NoteSearchFamily._()
    : super(
        retry: null,
        name: r'noteSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteSearchProvider call(String query) =>
      NoteSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'noteSearchProvider';
}
