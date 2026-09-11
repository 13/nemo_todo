import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

part 'app_release.freezed.dart';

@freezed
abstract class ReleaseAsset with _$ReleaseAsset {
  const factory ReleaseAsset({
    required String name,
    required String url,
    required int size,

    /// Hex digest GitHub publishes for the asset, without its algorithm
    /// prefix. Null for assets uploaded before GitHub recorded one.
    String? sha256,
  }) = _ReleaseAsset;
}

@freezed
abstract class AppRelease with _$AppRelease {
  const factory AppRelease({
    required AppVersion version,
    required String tag,
    required String notes,
    required List<ReleaseAsset> assets,
  }) = _AppRelease;
}
