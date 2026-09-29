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
    expect(json(await server.get('/healthz')), {
      'status': 'ok',
      'version': 'dev',
    });
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

  test(
    'health names the commit and build date once they are stamped',
    () async {
      server = await TestServer.start(
        version: '0.7.0',
        commit: '33f0001abc',
        builtAt: '2026-09-14T07:00:00Z',
      );
      expect(json(await server.get('/healthz')), {
        'status': 'ok',
        'version': '0.7.0',
        'commit': '33f0001abc',
        'builtAt': '2026-09-14T07:00:00Z',
      });
    },
  );

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

  test('a forwarding header cannot buy extra login attempts', () async {
    server = await TestServer.start(limiter: RateLimiter(max: 2));
    await server.signup('ben');
    Future<http.Response> login(String forwarded) => http.post(
      server.uri('/api/v1/auth/login'),
      headers: {
        'content-type': 'application/json',
        'x-forwarded-for': forwarded,
      },
      body: jsonEncode({'username': 'ben', 'password': 'password123'}),
    );

    expect((await login('1.1.1.1')).statusCode, 200);
    final third = await login('3.3.3.3');
    expect(
      third.statusCode,
      429,
      reason: 'a header the client controls must not reset the count',
    );
  });

  test('an oversized body is refused', () async {
    server = await TestServer.start();
    final token = await server.signup('ben');
    final big = await http.post(
      server.uri('/api/v1/sync'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $token',
      },
      body: '{"cursor":0,"changes":[],"pad":"${'x' * (1024 * 1024 + 64)}"}',
    );
    expect(big.statusCode, 413);
    expect(json(big), {'error': 'payload_too_large'});
  });

  test('fields of the wrong type are a bad request, not a crash', () async {
    server = await TestServer.start();
    final signup = await server.post('/api/v1/auth/signup', {
      'username': 1,
      'password': 2,
    });
    expect(signup.statusCode, 400);
    expect(json(signup), {'error': 'bad_request'});

    final token = await server.signup('ben');
    final member = await server.post('/api/v1/lists/l1/members', {
      'username': 7,
      'role': 'editor',
    }, token: token);
    expect(member.statusCode, 400);
    expect(json(member), {'error': 'bad_request'});
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

    // Handing the list over moves those powers with it, and hands them back
    // the same way, so the test leaves ownership where it found it.
    final handed = await server.post('/api/v1/lists/l1/owner', {
      'username': 'anna',
    }, token: ben);
    expect(handed.statusCode, 200, reason: handed.body);
    expect(
      (await server.post('/api/v1/lists/l1/owner', {
        'username': 'anna',
      }, token: ben)).statusCode,
      403,
      reason: 'the former owner cannot take it back',
    );
    final handedBack = await server.post('/api/v1/lists/l1/owner', {
      'username': 'ben',
    }, token: anna);
    expect(handedBack.statusCode, 200, reason: handedBack.body);
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

  test(
    'sends the web app compressed where it can, and never unasked',
    () async {
      final dir = await Directory.systemTemp.createTemp('nemo-web');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/index.html').writeAsString('<html>app</html>');
      const js = 'void main() {}';
      await File('${dir.path}/main.dart.js').writeAsString(js);
      await File('${dir.path}/main.dart.js.gz')
          .writeAsBytes(gzip.encode(utf8.encode(js)));
      // Dart has no brotli encoder; the server only passes the bytes on.
      const brotli = [0x0b, 0x06, 0x80, 0x76, 0x6f, 0x69, 0x64, 0x03];
      await File('${dir.path}/main.dart.js.br').writeAsBytes(brotli);
      await File('${dir.path}/worker.js').writeAsString(js);
      await File('${dir.path}/worker.js.gz')
          .writeAsBytes(gzip.encode(utf8.encode(js)));
      await File('${dir.path}/favicon.png').writeAsBytes([1, 2, 3]);
      server = await TestServer.start(webDir: dir.path);

      final client = HttpClient()..autoUncompress = false;
      addTearDown(client.close);
      Future<HttpClientResponse> fetch(
        String path, {
        String? encoding,
        DateTime? since,
      }) async {
        final request = await client.getUrl(server.uri(path));
        request.headers.removeAll('accept-encoding');
        if (encoding != null) request.headers.set('accept-encoding', encoding);
        if (since != null) request.headers.ifModifiedSince = since;
        return await request.close();
      }

      final br = await fetch('/main.dart.js', encoding: 'gzip, deflate, br');
      expect(br.statusCode, 200);
      expect(br.headers.value('content-encoding'), 'br');
      expect(br.headers.contentType?.mimeType, 'text/javascript');
      expect(br.headers.value('vary'), contains('accept-encoding'));
      expect(await br.fold(<int>[], (a, b) => a..addAll(b)), brotli);

      // Brotli is only offered over HTTPS; everywhere else gzip it is. So
      // is it for a file built without a brotli copy.
      final zipped = await fetch('/main.dart.js', encoding: 'gzip, deflate');
      expect(zipped.statusCode, 200);
      expect(zipped.headers.value('content-encoding'), 'gzip');
      expect(zipped.headers.contentType?.mimeType, 'text/javascript');
      expect(zipped.headers.value('vary'), contains('accept-encoding'));
      expect(zipped.headers.value('cache-control'), 'no-cache');
      final bytes = await zipped.fold(<int>[], (a, b) => a..addAll(b));
      expect(utf8.decode(gzip.decode(bytes)), js);

      final worker = await fetch('/worker.js', encoding: 'br, gzip');
      expect(worker.headers.value('content-encoding'), 'gzip');
      await worker.drain<void>();

      for (final encoding in [null, 'identity', 'gzip;q=0, br;q=0']) {
        final plain = await fetch('/main.dart.js', encoding: encoding);
        expect(plain.headers.value('content-encoding'), isNull);
        expect(plain.headers.value('vary'), contains('accept-encoding'));
        expect(await plain.transform(utf8.decoder).join(), js);
      }

      // Asking again is cheap: an unchanged file is a 304 either way.
      final later = DateTime.now().add(const Duration(minutes: 1));
      expect((await fetch('/main.dart.js', since: later)).statusCode, 304);
      expect(
        (await fetch(
          '/main.dart.js',
          encoding: 'gzip',
          since: later,
        )).statusCode,
        304,
      );

      // The browser echoes last-modified back, which HTTP dates carry to the
      // second only; a file changed within that second is still unchanged.
      // Linux keeps microseconds, which shelf_static alone gets wrong.
      Future<void> echoes(String path, {String? encoding}) async {
        final first = await fetch(path, encoding: encoding);
        await first.drain<void>();
        final again = await fetch(
          path,
          encoding: encoding,
          since: HttpDate.parse(first.headers.value('last-modified')!),
        );
        await again.drain<void>();
        expect(again.statusCode, 304, reason: '$path $encoding');
        expect(again.headers.value('cache-control'), 'no-cache');
      }

      final stamp = DateTime.utc(2026, 9, 29, 9, 0, 6, 583, 68);
      for (final name in [
        'index.html',
        'main.dart.js',
        'main.dart.js.gz',
        'main.dart.js.br',
      ]) {
        File('${dir.path}/$name').setLastModifiedSync(stamp);
      }
      await echoes('/main.dart.js');
      await echoes('/main.dart.js', encoding: 'gzip');
      await echoes('/main.dart.js', encoding: 'br');
      await echoes('/');
      await echoes('/lists/abc');

      // Files built without a compressed copy are sent as they are, and are
      // revalidated like everything else.
      final png = await fetch('/favicon.png', encoding: 'gzip');
      expect(png.headers.value('content-encoding'), isNull);
      expect(png.headers.value('cache-control'), 'no-cache');
      await png.drain<void>();
    },
  );

  test('serves each build under its own path, cached for good', () async {
    final dir = await Directory.systemTemp.createTemp('nemo-web');
    addTearDown(() => dir.delete(recursive: true));
    const page =
        '<html><head><base href="/"> '
        '<link rel="manifest" href="manifest.json"></head>app</html>';
    final index = File('${dir.path}/index.html')..writeAsStringSync(page);
    await File('${dir.path}/main.dart.js').writeAsString('js');
    await File('${dir.path}/main.dart.js.gz')
        .writeAsBytes(gzip.encode(utf8.encode('js')));
    await File('${dir.path}/manifest.json').writeAsString('{}');
    server = await TestServer.start(webDir: dir.path);

    final client = HttpClient()..autoUncompress = false;
    addTearDown(client.close);
    Future<(HttpClientResponse, String)> fetch(
      String path, {
      String? encoding,
      DateTime? since,
    }) async {
      final request = await client.getUrl(server.uri(path));
      request.headers.removeAll('accept-encoding');
      if (encoding != null) request.headers.set('accept-encoding', encoding);
      if (since != null) request.headers.ifModifiedSince = since;
      final response = await request.close();
      return (response, await response.transform(latin1.decoder).join());
    }

    String buildOf(String body) =>
        RegExp('<base href="/v/([0-9a-f]{12})/">').firstMatch(body)![1]!;

    // The page points everything it loads at this build's own path, but
    // leaves the manifest where it was: an installed app is known by it.
    final (root, body) = await fetch('/');
    expect(root.headers.value('cache-control'), 'no-cache');
    final build = buildOf(body);
    expect(body, contains('<link rel="manifest" href="/manifest.json">'));
    final (deep, deepBody) = await fetch('/lists/abc');
    expect(deep.statusCode, 200);
    expect(buildOf(deepBody), build);
    final (_, indexBody) = await fetch('/index.html');
    expect(buildOf(indexBody), build);

    // Nothing under a build's path ever changes, so it is never asked
    // about again; compressed or not, and the app routes under it too.
    const forGood = 'public, max-age=31536000, immutable';
    final (js, jsBody) = await fetch('/v/$build/main.dart.js');
    expect(js.statusCode, 200);
    expect(jsBody, 'js');
    expect(js.headers.value('cache-control'), forGood);
    final (zipped, _) = await fetch('/v/$build/main.dart.js', encoding: 'gzip');
    expect(zipped.headers.value('content-encoding'), 'gzip');
    expect(zipped.headers.value('cache-control'), forGood);
    final (start, startBody) = await fetch('/v/$build/');
    expect(start.statusCode, 200);
    expect(buildOf(startBody), build);
    expect(start.headers.value('cache-control'), 'no-cache');
    expect((await fetch('/v/$build/missing.js')).$1.statusCode, 404);

    // A tab still open on an older build gets what there is, but asks.
    final (old, oldBody) = await fetch('/v/0123456789ab/main.dart.js');
    expect(old.statusCode, 200);
    expect(oldBody, 'js');
    expect(old.headers.value('cache-control'), 'no-cache');
    // And so does a page from before builds had paths.
    final (plain, _) = await fetch('/main.dart.js');
    expect(plain.headers.value('cache-control'), 'no-cache');

    // An unchanged page is still a 304.
    final (again, _) = await fetch(
      '/',
      since: HttpDate.parse(root.headers.value('last-modified')!),
    );
    expect(again.statusCode, 304);

    // A new build is a new path.
    index
      ..writeAsStringSync('$page ')
      ..setLastModifiedSync(DateTime.now().add(const Duration(minutes: 1)));
    final (_, rebuilt) = await fetch('/');
    expect(buildOf(rebuilt), isNot(build));
  });

  test('acceptsEncoding reads accept-encoding', () {
    expect(acceptsEncoding(null, 'gzip'), isFalse);
    expect(acceptsEncoding('', 'gzip'), isFalse);
    expect(acceptsEncoding('gzip', 'gzip'), isTrue);
    expect(acceptsEncoding('br, gzip, deflate', 'gzip'), isTrue);
    expect(acceptsEncoding('br, gzip, deflate', 'br'), isTrue);
    expect(acceptsEncoding('gzip;q=0.5', 'gzip'), isTrue);
    expect(acceptsEncoding('gzip; q=0', 'gzip'), isFalse);
    expect(acceptsEncoding('*', 'br'), isTrue);
    expect(acceptsEncoding('br, deflate', 'gzip'), isFalse);
    expect(acceptsEncoding('gzip', 'br'), isFalse);
  });

  test('without a built web app the root answers 404', () async {
    server = await TestServer.start();
    expect((await server.get('/')).statusCode, 404);
  });

  test('the server says which build is answering', () async {
    server = await TestServer.start(version: '9.9.9');

    // Without signing in, and outside /api/v1, so it can be asked of a
    // server whose web app will not start.
    expect(json(await server.get('/healthz')), {
      'status': 'ok',
      'version': '9.9.9',
    });

    // And on every sync, so a connected app never has to ask separately.
    final token = await server.signup('ben');
    final body = json(
      await server.post('/api/v1/sync', {
        'cursor': 0,
        'changes': <Object>[],
      }, token: token),
    );
    expect(body['server_version'], '9.9.9');
  });
}
