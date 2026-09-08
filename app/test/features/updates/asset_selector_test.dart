import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/asset_selector.dart';

ReleaseAsset _asset(String name) =>
    ReleaseAsset(name: name, url: 'https://example.test/$name', size: 1);

final List<ReleaseAsset> _assets = [
  _asset('nemo-0.2.0+2-arm64-v8a.apk'),
  _asset('nemo-0.2.0+2-armeabi-v7a.apk'),
  _asset('nemo-0.2.0+2-x86_64.apk'),
  _asset('nemo-0.2.0+2-universal.apk'),
  _asset('SHA256SUMS.txt'),
];

void main() {
  test('takes the first supported abi, in the device order', () {
    expect(
      selectAsset(_assets, ['arm64-v8a', 'armeabi-v7a'])!.name,
      'nemo-0.2.0+2-arm64-v8a.apk',
    );
    // A 32 bit device lists only its own architecture.
    expect(
      selectAsset(_assets, ['armeabi-v7a'])!.name,
      'nemo-0.2.0+2-armeabi-v7a.apk',
    );
    expect(
      selectAsset(_assets, ['x86_64', 'x86'])!.name,
      'nemo-0.2.0+2-x86_64.apk',
    );
  });

  test('falls back to the universal build', () {
    expect(
      selectAsset(_assets, ['riscv64'])!.name,
      'nemo-0.2.0+2-universal.apk',
    );
    expect(selectAsset(_assets, [])!.name, 'nemo-0.2.0+2-universal.apk');
  });

  test('returns nothing when no apk fits', () {
    final onlyOther = [_asset('SHA256SUMS.txt'), _asset('sources.zip')];
    expect(selectAsset(onlyOther, ['arm64-v8a']), isNull);
    expect(selectAsset(const [], ['arm64-v8a']), isNull);
  });

  test('never offers a file that is not an apk', () {
    final trap = [_asset('nemo-0.2.0+2-arm64-v8a.apk.asc')];
    expect(selectAsset(trap, ['arm64-v8a']), isNull);
  });
}
