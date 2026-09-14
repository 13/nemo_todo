import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/build_info.dart';
import 'package:nemo/features/settings/data/server_build.dart';

void main() {
  test('a build nobody stamped is a local one with nothing to show', () {
    final info = BuildInfo.parse(commit: '', builtAt: '', channel: '');
    expect(info.channel, 'dev');
    expect(info.builtAt, isNull);
    expect(info.shortCommit, isNull);
  });

  test('stamped values are read, and a bad date is no date', () {
    final info = BuildInfo.parse(
      commit: ' 33f0001abcdef0123 ',
      builtAt: '2026-09-14T07:00:00Z',
      channel: 'release',
    );
    expect(info.commit, '33f0001abcdef0123');
    expect(info.shortCommit, '33f0001');
    expect(info.builtAt, DateTime.utc(2026, 9, 14, 7));
    expect(info.channel, 'release');
    expect(
      BuildInfo.parse(commit: '', builtAt: 'yesterday', channel: '').builtAt,
      isNull,
    );
    expect(shortenCommit('abc'), 'abc');
  });

  test('a server says as much about its build as it knows', () {
    final full = ServerBuild.fromJson(const {
      'status': 'ok',
      'version': '0.7.0',
      'commit': 'abc1234ffff',
      'builtAt': '2026-09-13T00:00:00Z',
    });
    expect(full.version, '0.7.0');
    expect(full.shortCommit, 'abc1234');
    expect(full.builtAt, DateTime.utc(2026, 9, 13));

    final older = ServerBuild.fromJson(const {
      'status': 'ok',
      'version': '0.6.0',
    });
    expect(older.commit, isNull);
    expect(older.builtAt, isNull);
  });
}
