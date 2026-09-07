import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

import 'support/rows.dart';
import 'support/test_server.dart';

void main() {
  late TestServer server;

  tearDown(() => server.close());

  test('health, signup, me, logout and auth errors', () async {
    server = await TestServer.start();
    expect(json(await server.get('/healthz')), {'status': 'ok'});
    final token = await server.signup('ben');
    final me = await server.get('/api/v1/auth/me', token: token);
    expect(json(me)['username'], 'ben');
    expect((await server.get('/api/v1/auth/me')).statusCode, 401);
    expect((await server.get('/api/v1/auth/me', token: 'bad')).statusCode, 401);
    expect(json(await server.post('/api/v1/auth/logout', {}, token: token)), {
      'ok': true,
    });
    expect((await server.get('/api/v1/auth/me', token: token)).statusCode, 401);
    final login = await server.post('/api/v1/auth/login', {
      'username': 'ben',
      'password': 'password123',
    });
    final fresh = json(login)['token'] as String;
    final wrong = await server.post('/api/v1/auth/login', {
      'username': 'ben',
      'password': 'nope',
    });
    expect(wrong.statusCode, 401);
    expect(json(wrong), {'error': 'invalid_credentials'});
    final bad = await http.post(
      server.uri('/api/v1/auth/login'),
      body: '{not json',
      headers: {'content-type': 'application/json'},
    );
    expect(bad.statusCode, 400);
    expect(json(bad), {'error': 'bad_json'});
    expect((await server.get('/api/v1/nope', token: fresh)).statusCode, 404);
    expect(json(await server.get('/api/v1/nope', token: fresh)), {
      'error': 'not_found',
    });
    expect((await server.get('/api/other')).statusCode, 404);
  });

  test('auth endpoints are rate limited per client', () async {
    server = await TestServer.start(limiter: RateLimiter(max: 2));
    await server.signup('ben');
    final second = await server.post('/api/v1/auth/login', {
      'username': 'ben',
      'password': 'password123',
    });
    expect(second.statusCode, 200);
    final third = await server.post('/api/v1/auth/login', {
      'username': 'ben',
      'password': 'password123',
    });
    expect(third.statusCode, 429);
    expect(json(third), {'error': 'too_many_requests'});
  });

  test('sync, sharing and events over HTTP', () async {
    server = await TestServer.start(now: () => fixedNow);
    final ben = await server.signup('ben');
    final anna = await server.signup('anna');
    final dev = deviceClock('dev');

    final annaEvents = <String>[];
    final client = http.Client();
    final streamed = await client.send(
      http.Request('GET', server.uri('/api/v1/events?token=$anna')),
    );
    expect(streamed.statusCode, 200);
    expect(streamed.headers['content-type'], startsWith('text/event-stream'));
    final done = Completer<void>();
    final sub = streamed.stream.transform(utf8.decoder).listen((chunk) {
      annaEvents.add(chunk);
      if (chunk.contains('event: changed') && !done.isCompleted) {
        done.complete();
      }
    });

    final pushed = await server.post(
      '/api/v1/sync',
      SyncRequest(
        changes: [
          SyncChange.list(list('l1', dev)),
          SyncChange.task(task('t1', 'l1', dev)),
        ],
        cursor: 0,
      ).toJson(),
      token: ben,
    );
    expect(pushed.statusCode, 200);
    final response = SyncResponse.fromJson(json(pushed));
    expect(response.changes, hasLength(2));

    final annaBefore = SyncResponse.fromJson(
      json(
        await server.post(
          '/api/v1/sync',
          const SyncRequest(cursor: 0).toJson(),
          token: anna,
        ),
      ),
    );
    expect(annaBefore.changes, isEmpty);

    final share = await server.post('/api/v1/lists/l1/members', {
      'username': 'anna',
      'role': 'editor',
    }, token: ben);
    expect(share.statusCode, 200, reason: share.body);
    await done.future.timeout(const Duration(seconds: 5));
    expect(annaEvents.join(), contains(': connected'));

    final memberList = json(
      await server.get('/api/v1/lists/l1/members', token: anna),
    );
    expect(memberList['members'], hasLength(2));

    final annaAfter = SyncResponse.fromJson(
      json(
        await server.post(
          '/api/v1/sync',
          SyncRequest(cursor: annaBefore.cursor).toJson(),
          token: anna,
        ),
      ),
    );
    expect(annaAfter.changes.map((c) => c.rowId), ['l1', 't1']);

    final forbidden = await server.post('/api/v1/lists/l1/members', {
      'username': 'ben',
    }, token: anna);
    expect(forbidden.statusCode, 403);
    final removed = await server.delete(
      '/api/v1/lists/l1/members/anna',
      token: ben,
    );
    expect(removed.statusCode, 200);
    expect(
      (await server.get('/api/v1/lists/l1/members', token: anna)).statusCode,
      404,
    );
    final noHeaderNoToken = await server.get('/api/v1/events');
    expect(noHeaderNoToken.statusCode, 401);

    await sub.cancel();
    client.close();
  });

  test('serves the web app with SPA fallback and security headers', () async {
    final dir = await Directory.systemTemp.createTemp('nemo-web');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/index.html').writeAsString('<html>app</html>');
    await File('${dir.path}/main.dart.js').writeAsString('js');
    server = await TestServer.start(
      webDir: dir.path,
      corsOrigins: ['http://localhost:5000'],
    );

    final root = await server.get('/');
    expect(root.statusCode, 200);
    expect(root.body, contains('app'));
    expect(root.headers['cache-control'], 'no-cache');
    expect(root.headers['x-content-type-options'], 'nosniff');
    expect(
      root.headers['content-security-policy'],
      contains("default-src 'self'"),
    );
    expect((await server.get('/main.dart.js')).body, 'js');
    final deep = await server.get('/lists/abc');
    expect(deep.statusCode, 200);
    expect(deep.body, contains('app'));
    expect((await server.get('/missing.png')).statusCode, 404);

    final preflight = await http.Client().send(
      http.Request('OPTIONS', server.uri('/api/v1/sync'))
        ..headers['origin'] = 'http://localhost:5000',
    );
    expect(preflight.statusCode, 204);
    expect(
      preflight.headers['access-control-allow-origin'],
      'http://localhost:5000',
    );
    final denied = await http.get(
      server.uri('/healthz'),
      headers: {'origin': 'http://evil.test'},
    );
    expect(denied.headers['access-control-allow-origin'], isNull);
  });

  test('without a built web app the root answers 404', () async {
    server = await TestServer.start();
    expect((await server.get('/')).statusCode, 404);
  });
}
