import 'package:nemo/features/updates/domain/app_release.dart';

/// The APK to download on a device reporting [supportedAbis], which Android
/// gives in the device's own order of preference. Falls back to the
/// universal build, which runs anywhere at three times the size.
ReleaseAsset? selectAsset(
  List<ReleaseAsset> assets,
  List<String> supportedAbis,
) {
  final apks = assets.where((a) => a.name.endsWith('.apk')).toList();
  for (final abi in supportedAbis) {
    for (final asset in apks) {
      if (asset.name.endsWith('-$abi.apk')) return asset;
    }
  }
  for (final asset in apks) {
    if (asset.name.endsWith('-universal.apk')) return asset;
  }
  return null;
}
