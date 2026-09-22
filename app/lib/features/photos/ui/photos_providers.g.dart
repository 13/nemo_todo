// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photos_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(photosByParent)
final photosByParentProvider = PhotosByParentFamily._();

final class PhotosByParentProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Photo>>,
          List<Photo>,
          Stream<List<Photo>>
        >
    with $FutureModifier<List<Photo>>, $StreamProvider<List<Photo>> {
  PhotosByParentProvider._({
    required PhotosByParentFamily super.from,
    required (PhotoParent, String) super.argument,
  }) : super(
         retry: null,
         name: r'photosByParentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$photosByParentHash();

  @override
  String toString() {
    return r'photosByParentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<Photo>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Photo>> create(Ref ref) {
    final argument = this.argument as (PhotoParent, String);
    return photosByParent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is PhotosByParentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$photosByParentHash() => r'a5c24c64c5e9379ea315d80daafe383f7d1cdb27';

final class PhotosByParentFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Photo>>, (PhotoParent, String)> {
  PhotosByParentFamily._()
    : super(
        retry: null,
        name: r'photosByParentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PhotosByParentProvider call(PhotoParent kind, String id) =>
      PhotosByParentProvider._(argument: (kind, id), from: this);

  @override
  String toString() => r'photosByParentProvider';
}

@ProviderFor(photoCounts)
final photoCountsProvider = PhotoCountsProvider._();

final class PhotoCountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, int>>,
          Map<String, int>,
          Stream<Map<String, int>>
        >
    with $FutureModifier<Map<String, int>>, $StreamProvider<Map<String, int>> {
  PhotoCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'photoCountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$photoCountsHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, int>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, int>> create(Ref ref) {
    return photoCounts(ref);
  }
}

String _$photoCountsHash() => r'b381220fa6b2ca97e4b63f2fdeaa8075a33c9fce';

/// The bytes of one picture, or null while nobody can hand them over.
///
/// Where downloads are not eager -- the web -- bytes the store does not
/// hold are fetched here, when the picture is shown: nothing else would
/// ever bring in a picture from another device, one the in-memory store
/// evicted, or any of them after a reload.

@ProviderFor(photoBytes)
final photoBytesProvider = PhotoBytesFamily._();

/// The bytes of one picture, or null while nobody can hand them over.
///
/// Where downloads are not eager -- the web -- bytes the store does not
/// hold are fetched here, when the picture is shown: nothing else would
/// ever bring in a picture from another device, one the in-memory store
/// evicted, or any of them after a reload.

final class PhotoBytesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// The bytes of one picture, or null while nobody can hand them over.
  ///
  /// Where downloads are not eager -- the web -- bytes the store does not
  /// hold are fetched here, when the picture is shown: nothing else would
  /// ever bring in a picture from another device, one the in-memory store
  /// evicted, or any of them after a reload.
  PhotoBytesProvider._({
    required PhotoBytesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'photoBytesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$photoBytesHash();

  @override
  String toString() {
    return r'photoBytesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return photoBytes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PhotoBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$photoBytesHash() => r'ab0e30c0188ad23b8eefb11ad8ae105e3237dca9';

/// The bytes of one picture, or null while nobody can hand them over.
///
/// Where downloads are not eager -- the web -- bytes the store does not
/// hold are fetched here, when the picture is shown: nothing else would
/// ever bring in a picture from another device, one the in-memory store
/// evicted, or any of them after a reload.

final class PhotoBytesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  PhotoBytesFamily._()
    : super(
        retry: null,
        name: r'photoBytesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The bytes of one picture, or null while nobody can hand them over.
  ///
  /// Where downloads are not eager -- the web -- bytes the store does not
  /// hold are fetched here, when the picture is shown: nothing else would
  /// ever bring in a picture from another device, one the in-memory store
  /// evicted, or any of them after a reload.

  PhotoBytesProvider call(String sha256) =>
      PhotoBytesProvider._(argument: sha256, from: this);

  @override
  String toString() => r'photoBytesProvider';
}

/// Pictures this device holds that the server has not taken yet.

@ProviderFor(pendingPhotoHashes)
final pendingPhotoHashesProvider = PendingPhotoHashesProvider._();

/// Pictures this device holds that the server has not taken yet.

final class PendingPhotoHashesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// Pictures this device holds that the server has not taken yet.
  PendingPhotoHashesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingPhotoHashesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingPhotoHashesHash();

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    return pendingPhotoHashes(ref);
  }
}

String _$pendingPhotoHashesHash() =>
    r'df61d08ee4a3b06e1872605618d06200e7a6e93a';
