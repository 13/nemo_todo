import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_release.dart';

/// Serves fixed bytes so the test never touches the network.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes, {this.fail = false});

  final List<int> bytes;
  final bool fail;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final payload = List<int>.generate(4096, (i) => i % 256);
  final digest = sha256.convert(payload).toString();
  late Directory dir;

  Dio dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;
  UpdateDownloader downloader(HttpClientAdapter adapter) =>
      UpdateDownloader(dioWith(adapter), directory: () async => dir);

  ReleaseAsset asset({String? sha}) => ReleaseAsset(
    name: 'nemo-0.2.0+2-arm64-v8a.apk',
    url: 'https://example.test/nemo.apk',
    size: 4096,
    sha256: sha,
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('nemo-update'));
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'writes the file, reports progress and keeps it when the hash matches',
    () async {
      final seen = <double>[];
      final file = await downloader(_BytesAdapter(payload))
          .download(asset(sha: digest), onProgress: seen.add);

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), payload.length);
      expect(file.path, endsWith('nemo-0.2.0+2-arm64-v8a.apk'));
      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
    },
  );

  test('a wrong hash deletes the file and fails', () async {
    await expectLater(
      downloader(_BytesAdapter(payload)).download(asset(sha: 'deadbeef')),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.failure,
          'failure',
          UpdateFailure.malformed,
        ),
      ),
    );
    expect(dir.listSync(), isEmpty, reason: 'nothing half-trusted is left');
  });

  test('an asset with no published hash is accepted', () async {
    final file = await downloader(_BytesAdapter(payload)).download(asset());
    expect(file.existsSync(), isTrue);
  });

  test('a failed transfer leaves nothing behind', () async {
    await expectLater(
      downloader(_BytesAdapter(payload, fail: true))
          .download(asset(sha: digest)),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.failure,
          'failure',
          UpdateFailure.network,
        ),
      ),
    );
    expect(dir.listSync(), isEmpty);
  });
}
