// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievements_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(completionStats)
final completionStatsProvider = CompletionStatsProvider._();

final class CompletionStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CompletionStats>,
          CompletionStats,
          Stream<CompletionStats>
        >
    with $FutureModifier<CompletionStats>, $StreamProvider<CompletionStats> {
  CompletionStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'completionStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$completionStatsHash();

  @$internal
  @override
  $StreamProviderElement<CompletionStats> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<CompletionStats> create(Ref ref) {
    return completionStats(ref);
  }
}

String _$completionStatsHash() => r'de238d4e50a0ed46e79593690b664271dd30bda8';
