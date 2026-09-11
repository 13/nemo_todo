import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

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

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(validateStatus: (s) => s != null && s < 400))
      ..httpClientAdapter = adapter;

const Map<String, Object> _release = {
  'tag_name': 'v0.2.0',
  'body': '- Faster search\n- Fixed reminders',
  'assets': [
    {
      'name': 'nemo-0.2.0+2-arm64-v8a.apk',
      'browser_download_url': 'https://example.test/arm64.apk',
      'size': 24000000,
      'digest': 'sha256:abc123',
    },
    {
      'name': 'SHA256SUMS.txt',
      'browser_download_url': 'https://example.test/sums',
      'size': 120,
    },
  ],
};

void main() {
  test('maps a release, its notes and its assets', () async {
    final adapter = _FakeAdapter((_) => _json(_release));
    final release = await GithubReleaseClient(_dio(adapter)).latest();

    expect(release.version, const AppVersion(0, 2, 0));
    expect(release.tag, 'v0.2.0');
    expect(release.notes, contains('Faster search'));
    expect(release.assets, hasLength(2));
    final apk = release.assets.first;
    expect(apk.name, 'nemo-0.2.0+2-arm64-v8a.apk');
    expect(apk.url, 'https://example.test/arm64.apk');
    expect(apk.size, 24000000);
    // The digest arrives prefixed; the bare hash is what a checksum needs.
    expect(apk.sha256, 'abc123');
    expect(release.assets.last.sha256, isNull);

    final sent = adapter.requests.single;
    expect(
      sent.uri.toString(),
      'https://api.github.com/repos/13/nemo_todo/releases/latest',
    );
    expect(sent.headers['Accept'], 'application/vnd.github+json');
  });

  test('a tag that is not a version is malformed', () async {
    final adapter = _FakeAdapter(
      (_) => _json({..._release, 'tag_name': 'nightly'}),
    );
    await expectLater(
      GithubReleaseClient(_dio(adapter)).latest(),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.failure,
          'failure',
          UpdateFailure.malformed,
        ),
      ),
    );
  });

  test('maps the statuses that matter', () async {
    Future<void> expectFailure(int status, UpdateFailure failure) async {
      final client = GithubReleaseClient(
        _dio(_FakeAdapter((_) => _json({'message': 'no'}, status: status))),
      );
      await expectLater(
        client.latest(),
        throwsA(
          isA<UpdateException>().having((e) => e.failure, 'failure', failure),
        ),
      );
    }

    await expectFailure(403, UpdateFailure.rateLimited);
    await expectFailure(404, UpdateFailure.notFound);
    await expectFailure(500, UpdateFailure.network);
  });

  test('an unreachable host is a network failure', () async {
    final client = GithubReleaseClient(
      _dio(
        _FakeAdapter(
          (options) => throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          ),
        ),
      ),
    );
    await expectLater(
      client.latest(),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.failure,
          'failure',
          UpdateFailure.network,
        ),
      ),
    );
  });
}
