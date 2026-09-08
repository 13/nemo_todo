import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';

import '../../support/fake_updates.dart';
import '../../support/test_db.dart';

void main() {
  late FakeReleaseClient client;
  late FakeDownloader downloader;
  late FakeInstaller installer;
  late File apk;
  late DateTime now;

  ProviderContainer container({bool supported = true}) {
    final db = testDatabase();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          const AppBootstrap(
            nodeId: 'test',
            hlcLast: null,
            themeMode: ThemeMode.system,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        updatesSupportedProvider.overrideWithValue(supported),
        currentVersionProvider.overrideWith(
          (_) async => const AppVersion(0, 1, 0),
        ),
        deviceAbisProvider.overrideWith((_) async => ['arm64-v8a']),
        releaseClientProvider.overrideWithValue(client),
        updateDownloaderProvider.overrideWithValue(downloader),
        apkInstallerProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    now = DateTime(2026, 9, 8, 9);
    apk = File('${Directory.systemTemp.createTempSync('nemo-c').path}/n.apk')
      ..writeAsStringSync('apk');
    client = FakeReleaseClient();
    downloader = FakeDownloader(apk);
    installer = FakeInstaller();
  });
  tearDown(() => apk.parent.deleteSync(recursive: true));

  test('a newer release becomes available with its asset', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    final state = c.read(updateControllerProvider);
    expect(state, isA<UpdateAvailable>());
    expect(
      (state as UpdateAvailable).release.version,
      const AppVersion(0, 2, 0),
    );
    expect(state.asset.name, endsWith('-arm64-v8a.apk'));
  });

  test('the running version or older means up to date', () async {
    client.release = releaseFixture(version: const AppVersion(0, 1, 0));
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(c.read(updateControllerProvider), isA<UpToDate>());
  });

  test(
    'an automatic check is silent about failure, a manual one is not',
    () async {
      client.failure = UpdateFailure.network;
      final c = container();
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider), isA<UpdateIdle>());

      await c.read(updateControllerProvider.notifier).check(manual: true);
      expect(c.read(updateControllerProvider), isA<UpdateFailed>());
    },
  );

  test('automatic checks run once a day, manual ones always', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 1);

    now = now.add(const Duration(hours: 3));
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 1, reason: 'still inside the day');

    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(client.calls, 2, reason: 'asking directly always asks');

    now = now.add(const Duration(days: 1));
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 3);
  });

  test(
    'a dismissed version stays dismissed until a newer one arrives',
    () async {
      final c = container();
      await c.read(updateControllerProvider.notifier).check(manual: true);
      await c.read(updateControllerProvider.notifier).dismiss();
      expect(c.read(updateControllerProvider), isA<UpdateIdle>());
      expect(
        await KvStore(c.read(appDatabaseProvider)).get(KvKeys.dismissedUpdate),
        '0.2.0',
      );

      now = now.add(const Duration(days: 2));
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider), isA<UpdateIdle>());

      client.release = releaseFixture(version: const AppVersion(0, 3, 0));
      now = now.add(const Duration(days: 2));
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider), isA<UpdateAvailable>());
    },
  );

  test('download reports progress then holds the file', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    final state = c.read(updateControllerProvider);
    expect(state, isA<UpdateReady>());
    expect((state as UpdateReady).file.path, apk.path);
  });

  test('a broken download is reported and can be retried', () async {
    downloader.failure = UpdateFailure.malformed;
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    expect(c.read(updateControllerProvider), isA<UpdateFailed>());
  });

  test('install hands the file over', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    await c.read(updateControllerProvider.notifier).install();
    expect(installer.installed, [apk.path]);
  });

  test('where updates are unsupported nothing is asked', () async {
    final c = container(supported: false);
    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(client.calls, 0);
    expect(c.read(updateControllerProvider), isA<UpdateIdle>());
  });
}
