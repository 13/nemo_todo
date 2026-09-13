import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';

import '../../support/fake_sync.dart';
import '../../support/test_db.dart';

void main() {
  const hash =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  late AppDatabase db;
  late MemoryPhotoStore store;
  late FakeSyncClient client;

  /// A container over the in-memory database, the memory store and the
  /// fake server, downloading on demand the way the web app does.
  Future<ProviderContainer> container({
    bool connected = true,
    bool eager = false,
  }) async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          const AppBootstrap(
            nodeId: 'device',
            hlcLast: null,
            themeMode: ThemeMode.system,
            serverUrl: 'https://nemo.test',
            username: 'ben',
          ),
        ),
        nowProvider.overrideWithValue(() => testNow),
        authStorageProvider.overrideWithValue(MemoryAuthStorage('secret')),
        syncClientFactoryProvider.overrideWithValue((_, _) => client),
        photoStoreProvider.overrideWithValue(store),
        photoDownloadEagerProvider.overrideWithValue(eager),
      ],
    );
    addTearDown(c.dispose);
    if (connected) await c.read(authControllerProvider.notifier).restore();
    return c;
  }

  /// Reads the bytes once, the way a thumbnail on screen would, then lets
  /// the provider go.
  Future<Uint8List?> show(ProviderContainer c) async {
    final sub = c.listen(photoBytesProvider(hash).future, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  setUp(() {
    db = testDatabase();
    store = MemoryPhotoStore();
    client = FakeSyncClient([])..blobs[hash] = Uint8List.fromList([1, 2, 3]);
  });
  tearDown(() => db.close());

  test('bytes this device does not hold are fetched when shown', () async {
    final c = await container();

    expect(await show(c), [1, 2, 3]);
    expect(client.downloaded, [hash]);
    expect(await store.get(hash), [1, 2, 3]);
    final blob = await (db.select(
      db.blobs,
    )..where((t) => t.sha256.equals(hash))).getSingle();
    expect(blob.state, 'synced');
    expect(blob.byteSize, 3);

    c.invalidate(photoBytesProvider(hash));
    expect(await show(c), [1, 2, 3]);
    expect(client.downloaded, [hash], reason: 'held now, so not fetched again');
  });

  test('without an account nothing is fetched', () async {
    final c = await container(connected: false);

    expect(await show(c), isNull);
    expect(client.downloaded, isEmpty);
  });

  test('a picture the server will not hand over shows as missing', () async {
    client.blobFailures[hash] = const ApiError(404, 'not_found');
    final c = await container();

    expect(await show(c), isNull);
    expect(await store.get(hash), isNull);
  });

  test('where downloads are eager the sync fetches, not the screen', () async {
    final c = await container(eager: true);

    expect(await show(c), isNull);
    expect(client.downloaded, isEmpty);
  });
}
