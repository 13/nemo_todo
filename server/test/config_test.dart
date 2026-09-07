import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  test('defaults', () {
    final c = Config.fromEnv({});
    expect(c.port, 8080);
    expect(c.dbPath, '/data/nemo.db');
    expect(c.allowSignup, isNull);
    expect(c.webDir, '/app/web');
    expect(c.corsOrigins, isEmpty);
    expect(c.nodeId, 'server');
  });

  test('reads every variable', () {
    final c = Config.fromEnv({
      'NEMO_PORT': '9000',
      'NEMO_DB': '/tmp/x.db',
      'NEMO_ALLOW_SIGNUP': 'false',
      'NEMO_WEB_DIR': '/srv/web',
      'NEMO_CORS_ORIGINS': 'http://localhost:5000, http://a.test ,',
      'NEMO_NODE_ID': 'srv1',
    });
    expect(c.port, 9000);
    expect(c.dbPath, '/tmp/x.db');
    expect(c.allowSignup, isFalse);
    expect(c.webDir, '/srv/web');
    expect(c.corsOrigins, ['http://localhost:5000', 'http://a.test']);
    expect(c.nodeId, 'srv1');
    expect(Config.fromEnv({'NEMO_ALLOW_SIGNUP': 'TRUE'}).allowSignup, isTrue);
    expect(Config.fromEnv({'NEMO_ALLOW_SIGNUP': 'maybe'}).allowSignup, isNull);
  });

  test('invalid port throws', () {
    expect(() => Config.fromEnv({'NEMO_PORT': 'x'}), throwsFormatException);
  });
}
