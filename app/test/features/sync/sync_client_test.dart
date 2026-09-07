import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo_core/nemo_core.dart';

/// Answers requests from a script instead of a network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(validateStatus: (s) => s != null && s < 400))
      ..httpClientAdapter = adapter;

ResponseBody _json(Map<String, dynamic> body, {int status = 200}) =>
    ResponseBody.fromString(
      // Dio decodes by content type.
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _encode(Map<String, dynamic> body) => const JsonEncoder().convert(body);

void main() {
  const task = Task(
    id: 't1',
    listId: 'l1',
    title: 'Buy milk',
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
  );

  test('normalises and validates base urls', () {
    expect(SyncClient.normaliseBaseUrl('https://a.test/// '), 'https://a.test');
    expect(SyncClient.isValidBaseUrl('https://nemo.example.com'), isTrue);
    expect(SyncClient.isValidBaseUrl('http://192.168.1.5:8080/'), isTrue);
    expect(SyncClient.isValidBaseUrl('nemo.example.com'), isFalse);
    expect(SyncClient.isValidBaseUrl('ftp://a.test'), isFalse);
    expect(SyncClient.isValidBaseUrl(''), isFalse);
  });

  test('sync posts the request and parses the response', () async {
    final adapter = _FakeAdapter(
      (_) => _json(
        const SyncResponse(
          cursor: 7,
          serverHlc: '0000000000009-0000-srv',
          changes: [SyncChange.task(task)],
        ).toJson(),
      ),
    );
    final client = SyncClient(
      _dio(adapter),
      baseUrl: 'https://nemo.test/',
      token: 'secret',
    );
    final response = await client.sync(const SyncRequest(cursor: 3));
    expect(response.cursor, 7);
    expect((response.changes.single as SyncChangeTask).row.title, 'Buy milk');
    final sent = adapter.requests.single;
    expect(sent.uri.toString(), 'https://nemo.test/api/v1/sync');
    expect(sent.headers['authorization'], 'Bearer secret');
    expect((sent.data as Map<String, dynamic>)['cursor'], 3);
  });

  test('members, share and unshare hit the right endpoints', () async {
    final adapter = _FakeAdapter(
      (options) => options.method == 'GET'
          ? _json({
              'members': [
                {'username': 'ben', 'role': 'owner'},
              ],
            })
          : _json({'ok': true}),
    );
    final client = SyncClient(
      _dio(adapter),
      baseUrl: 'https://nemo.test',
      token: 'secret',
    );
    expect((await client.members('l1')).single.username, 'ben');
    await client.share('l1', 'anna', MemberRole.editor);
    await client.unshare('l1', 'anna');
    await client.logout();
    expect(adapter.requests.map((r) => '${r.method} ${r.uri.path}'), [
      'GET /api/v1/lists/l1/members',
      'POST /api/v1/lists/l1/members',
      'DELETE /api/v1/lists/l1/members/anna',
      'POST /api/v1/auth/logout',
    ]);
    expect(
      (adapter.requests[1].data as Map<String, dynamic>)['role'],
      'editor',
    );
  });

  test('server errors become ApiError with the server code', () async {
    final adapter = _FakeAdapter(
      (_) => _json({'error': 'forbidden'}, status: 403),
    );
    final client = SyncClient(
      _dio(adapter),
      baseUrl: 'https://nemo.test',
      token: 'secret',
    );
    await expectLater(
      client.sync(const SyncRequest(cursor: 0)),
      throwsA(
        isA<ApiError>()
            .having((e) => e.status, 'status', 403)
            .having((e) => e.code, 'code', 'forbidden')
            .having((e) => e.isUnauthorized, 'isUnauthorized', false),
      ),
    );
  });

  test('a 401 is recognised and a dead server reads as offline', () async {
    final unauthorised = SyncClient(
      _dio(_FakeAdapter((_) => _json({'error': 'unauthorized'}, status: 401))),
      baseUrl: 'https://nemo.test',
      token: 'stale',
    );
    await expectLater(
      unauthorised.sync(const SyncRequest(cursor: 0)),
      throwsA(isA<ApiError>().having((e) => e.isUnauthorized, 'is401', true)),
    );

    final dead = SyncClient(
      _dio(
        _FakeAdapter(
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'no route',
          ),
        ),
      ),
      baseUrl: 'https://nemo.test',
      token: 'secret',
    );
    await expectLater(
      dead.sync(const SyncRequest(cursor: 0)),
      throwsA(
        isA<ApiError>()
            .having((e) => e.isOffline, 'isOffline', true)
            .having((e) => e.code, 'code', 'network'),
      ),
    );
  });

  test('authenticate signs in and signs up on the matching path', () async {
    final adapter = _FakeAdapter(
      (_) => _json({'token': 'abc', 'username': 'ben'}),
    );
    final dio = _dio(adapter);
    final session = await SyncClient.authenticate(
      dio,
      baseUrl: 'https://nemo.test/',
      username: 'ben',
      password: 'password123',
      signUp: false,
    );
    expect(session.token, 'abc');
    expect(session.username, 'ben');
    await SyncClient.authenticate(
      dio,
      baseUrl: 'https://nemo.test',
      username: 'ben',
      password: 'password123',
      signUp: true,
    );
    expect(adapter.requests.map((r) => r.uri.path), [
      '/api/v1/auth/login',
      '/api/v1/auth/signup',
    ]);
  });
}
