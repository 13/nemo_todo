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
    expect(c.trustedProxyHops, 0, reason: 'no proxy is assumed in front');
    expect(c.version, 'dev', reason: 'a build nobody stamped is a dev build');
    expect(c.commit, isNull);
    expect(c.builtAt, isNull);
  });

  test('reads every variable', () {
    final c = Config.fromEnv({
      'NEMO_PORT': '9000',
      'NEMO_DB': '/tmp/x.db',
      'NEMO_ALLOW_SIGNUP': 'false',
      'NEMO_WEB_DIR': '/srv/web',
      'NEMO_CORS_ORIGINS': 'http://localhost:5000, http://a.test ,',
      'NEMO_NODE_ID': 'srv1',
      'NEMO_TRUSTED_PROXY_HOPS': '1',
      'NEMO_VERSION': '0.4.0',
      'NEMO_COMMIT': '33f0001abc',
      'NEMO_BUILD_DATE': '2026-09-14T07:00:00Z',
    });
    expect(c.port, 9000);
    expect(c.dbPath, '/tmp/x.db');
    expect(c.allowSignup, isFalse);
    expect(c.webDir, '/srv/web');
    expect(c.corsOrigins, ['http://localhost:5000', 'http://a.test']);
    expect(c.nodeId, 'srv1');
    expect(c.trustedProxyHops, 1);
    expect(c.version, '0.4.0');
    expect(c.commit, '33f0001abc');
    expect(c.builtAt, '2026-09-14T07:00:00Z');
    expect(Config.fromEnv({'NEMO_ALLOW_SIGNUP': 'TRUE'}).allowSignup, isTrue);
    expect(Config.fromEnv({'NEMO_ALLOW_SIGNUP': 'maybe'}).allowSignup, isNull);
  });

  test('blob settings come from the environment', () {
    final config = Config.fromEnv({
      'NEMO_BLOB_DIR': '/srv/blobs',
      'NEMO_MAX_BLOB_BYTES': '1024',
      'NEMO_ACCOUNT_QUOTA_BYTES': '4096',
    });
    expect(config.blobDir, '/srv/blobs');
    expect(config.maxBlobBytes, 1024);
    expect(config.accountQuotaBytes, 4096);

    const fallback = Config();
    expect(fallback.blobDir, '/data/blobs');
    expect(fallback.maxBlobBytes, 5 * 1024 * 1024);
    expect(fallback.accountQuotaBytes, 500 * 1024 * 1024);
  });

  test('invalid port throws', () {
    expect(() => Config.fromEnv({'NEMO_PORT': 'x'}), throwsFormatException);
    expect(
      () => Config.fromEnv({'NEMO_TRUSTED_PROXY_HOPS': 'x'}),
      throwsFormatException,
    );
  });
}
