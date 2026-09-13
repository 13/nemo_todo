import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

import 'support/rows.dart';
import 'support/test_server.dart';

void main() {
  late TestServer server;

  tearDown(() => server.close());

  /// Pushes a list, a task and a photo naming [hash], as [token]'s owner.
  Future<void> attach(String token, String hash) async {
    final clock = deviceClock('ben');
    final request = SyncRequest(
      cursor: 0,
      changes: [
        SyncChange.list(list('l1', clock)),
        SyncChange.task(task('t1', 'l1', clock)),
        SyncChange.photo(photo('p1', 't1', clock, sha: hash)),
      ],
    );
    final response = await server.post(
      '/api/v1/sync',
      request.toJson(),
      token: token,
    );
    expect(response.statusCode, 200);
  }

  test(
    'uploads bytes, refuses a mismatched hash, and serves them back',
    () async {
      server = await TestServer.start();
      final token = await server.signup('ben');
      final bytes = utf8.encode('a tiny picture');
      final hash = sha256.convert(bytes).toString();

      final wrong = await server.putBytes(
        '/api/v1/blobs/${'b' * 64}',
        bytes,
        token: token,
      );
      expect(wrong.statusCode, 400);
      expect(jsonDecode(wrong.body), {'error': 'hash_mismatch'});

      final first = await server.putBytes(
        '/api/v1/blobs/$hash',
        bytes,
        token: token,
      );
      expect(first.statusCode, 200);
      // A second upload of the same bytes stores nothing new.
      final again = await server.putBytes(
        '/api/v1/blobs/$hash',
        bytes,
        token: token,
      );
      expect(again.statusCode, 200);
      expect(await server.db.select(server.db.blobs).get(), hasLength(1));

      await attach(token, hash);
      final fetched = await server.get('/api/v1/blobs/$hash', token: token);
      expect(fetched.statusCode, 200);
      expect(fetched.bodyBytes, bytes);
    },
  );

  test(
    'bytes nobody has attached to a task you can see are not found',
    () async {
      server = await TestServer.start();
      final ben = await server.signup('ben');
      final mallory = await server.signup('mallory');
      final bytes = utf8.encode('private');
      final hash = sha256.convert(bytes).toString();
      await server.putBytes('/api/v1/blobs/$hash', bytes, token: ben);
      await attach(ben, hash);

      final denied = await server.get('/api/v1/blobs/$hash', token: mallory);
      expect(denied.statusCode, 404);
      expect(jsonDecode(denied.body), {'error': 'not_found'});
      expect((await server.get('/api/v1/blobs/$hash')).statusCode, 401);
    },
  );

  test(
    'a blob over the cap is refused and a full account is told so',
    () async {
      server = await TestServer.start(maxBlobBytes: 8, accountQuotaBytes: 16);
      final token = await server.signup('ben');

      final big = List.filled(9, 1);
      final tooBig = await server.putBytes(
        '/api/v1/blobs/${sha256.convert(big)}',
        big,
        token: token,
      );
      expect(tooBig.statusCode, 413);
      expect(jsonDecode(tooBig.body), {'error': 'blob_too_large'});

      for (final fill in [2, 3]) {
        final bytes = List.filled(8, fill);
        final ok = await server.putBytes(
          '/api/v1/blobs/${sha256.convert(bytes)}',
          bytes,
          token: token,
        );
        expect(ok.statusCode, 200);
      }
      final over = List.filled(8, 4);
      final full = await server.putBytes(
        '/api/v1/blobs/${sha256.convert(over)}',
        over,
        token: token,
      );
      expect(full.statusCode, 507);
      expect(jsonDecode(full.body), {'error': 'quota_exceeded'});
    },
  );

  // Controller decision: a malformed hash must never reach BlobStore.fileFor,
  // which interpolates it into a filesystem path with no validation of its
  // own.
  test('an upload naming a malformed hash is refused, not stored', () async {
    server = await TestServer.start();
    final token = await server.signup('ben');
    final bytes = utf8.encode('whatever');

    // Uppercase hex is not the lowercase form photo rows carry.
    final upper = await server.putBytes(
      '/api/v1/blobs/${sha256.convert(bytes).toString().toUpperCase()}',
      bytes,
      token: token,
    );
    expect(upper.statusCode, 400);
    expect(jsonDecode(upper.body), {'error': 'invalid_hash'});

    // Not hex at all.
    final notHex = await server.putBytes(
      '/api/v1/blobs/${'g' * 64}',
      bytes,
      token: token,
    );
    expect(notHex.statusCode, 400);
    expect(jsonDecode(notHex.body), {'error': 'invalid_hash'});

    // Wrong length.
    final tooShort = await server.putBytes(
      '/api/v1/blobs/${'a' * 63}',
      bytes,
      token: token,
    );
    expect(tooShort.statusCode, 400);
    expect(jsonDecode(tooShort.body), {'error': 'invalid_hash'});

    expect(await server.db.select(server.db.blobs).get(), isEmpty);
  });

  test('a get for a malformed hash is not found, not a server error', () async {
    server = await TestServer.start();
    final token = await server.signup('ben');

    final upper = await server.get('/api/v1/blobs/${'A' * 64}', token: token);
    expect(upper.statusCode, 404);
    expect(jsonDecode(upper.body), {'error': 'not_found'});
  });

  // shelf_router's <hash> segment cannot itself contain a "/", so a
  // traversal-shaped path can never reach this route over HTTP - but nothing
  // stops a value from arriving in the database via a photo push. The
  // service-level guard is what actually protects `BlobStore.fileFor`; see
  // blob_store_test.dart's `isValidHash` test and sync_service_test.dart's
  // 'a photo whose sha256 is not a valid hash is refused' for the
  // traversal-shaped values that never reach an HTTP route segment.
  test(
    'a get whose hash segment is the maximum length but not hex is 404',
    () async {
      server = await TestServer.start();
      final token = await server.signup('ben');

      final dots = await server.get('/api/v1/blobs/${'.' * 64}', token: token);
      expect(dots.statusCode, 404);
      expect(jsonDecode(dots.body), {'error': 'not_found'});
    },
  );
}
