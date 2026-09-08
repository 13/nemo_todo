import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

void main() {
  test('parses plain, tagged and build-suffixed versions', () {
    expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('0.1.0+7'), const AppVersion(0, 1, 0));
    expect(AppVersion.tryParse(' v2.0.0 '), const AppVersion(2, 0, 0));
  });

  test('rejects anything that is not three numbers', () {
    for (final input in ['', 'v', '1.2', '1.2.3.4', 'nightly', '1.2.x']) {
      expect(AppVersion.tryParse(input), isNull, reason: input);
    }
  });

  test('compares by major, then minor, then patch', () {
    expect(
      const AppVersion(1, 0, 0).isNewerThan(const AppVersion(0, 9, 9)),
      isTrue,
    );
    expect(
      const AppVersion(0, 2, 0).isNewerThan(const AppVersion(0, 1, 9)),
      isTrue,
    );
    expect(
      const AppVersion(0, 1, 2).isNewerThan(const AppVersion(0, 1, 1)),
      isTrue,
    );
    expect(
      const AppVersion(0, 1, 1).isNewerThan(const AppVersion(0, 1, 1)),
      isFalse,
    );
    expect(
      const AppVersion(0, 1, 0).isNewerThan(const AppVersion(0, 1, 1)),
      isFalse,
    );
    // Ten is greater than nine, which string comparison gets wrong.
    expect(
      const AppVersion(0, 10, 0).isNewerThan(const AppVersion(0, 9, 0)),
      isTrue,
    );
  });

  test('prints back the way it came in', () {
    expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
  });
}
