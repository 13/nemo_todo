import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/domain/asset_selector.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_controller.g.dart';

/// How long an automatic check waits before asking again.
const updateCheckInterval = Duration(hours: 24);

final releaseClientProvider = Provider<GithubReleaseClient>(
  (ref) => GithubReleaseClient(ref.watch(dioProvider)),
);

final updateDownloaderProvider = Provider<UpdateDownloader>(
  (ref) => UpdateDownloader(ref.watch(dioProvider)),
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => ref.watch(updatesSupportedProvider)
      ? SystemApkInstaller()
      : const UnsupportedApkInstaller(),
);

final currentVersionProvider = FutureProvider<AppVersion>((_) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
});

final deviceAbisProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(updatesSupportedProvider)) return const [];
  final android = await DeviceInfoPlugin().androidInfo;
  return android.supportedAbis;
});

@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  @override
  UpdateState build() => const UpdateIdle();

  /// Looks for a newer release. An automatic check stays quiet: it obeys
  /// the daily interval, skips a version the user waved away, and says
  /// nothing when the network is not there.
  Future<void> check({bool manual = false}) async {
    if (!ref.read(updatesSupportedProvider)) return;
    final kv = ref.read(kvStoreProvider);
    final now = ref.read(nowProvider)();
    if (!manual && !await _dueForCheck(kv, now)) return;

    state = const UpdateChecking();
    try {
      final release = await ref.read(releaseClientProvider).latest();
      await kv.set(KvKeys.lastUpdateCheck, '${now.millisecondsSinceEpoch}');
      final current = await ref.read(currentVersionProvider.future);
      if (!release.version.isNewerThan(current)) {
        state = UpToDate(now);
        return;
      }
      if (!manual &&
          await kv.get(KvKeys.dismissedUpdate) == release.version.toString()) {
        state = const UpdateIdle();
        return;
      }
      final asset = selectAsset(
        release.assets,
        await ref.read(deviceAbisProvider.future),
      );
      state = asset == null
          ? const UpdateFailed(UpdateFailure.notFound)
          : UpdateAvailable(release, asset);
    } on UpdateException catch (e) {
      state = manual ? UpdateFailed(e.failure) : const UpdateIdle();
    }
  }

  Future<bool> _dueForCheck(KvStore kv, DateTime now) async {
    final raw = await kv.get(KvKeys.lastUpdateCheck);
    final last = int.tryParse(raw ?? '');
    if (last == null) return true;
    final since = now.difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since >= updateCheckInterval;
  }

  Future<void> download() async {
    final available = state;
    if (available is! UpdateAvailable) return;
    state = const UpdateDownloading(0);
    try {
      final file = await ref
          .read(updateDownloaderProvider)
          .download(
            available.asset,
            onProgress: (p) => state = UpdateDownloading(p),
          );
      state = UpdateReady(file, available.release);
    } on UpdateException catch (e) {
      state = UpdateFailed(e.failure);
    }
  }

  Future<void> install() async {
    final ready = state;
    if (ready is! UpdateReady) return;
    await ref.read(apkInstallerProvider).install(ready.file);
  }

  /// Stops this version from asking again. A newer one still will.
  Future<void> dismiss() async {
    final current = state;
    if (current is UpdateAvailable) {
      await ref
          .read(kvStoreProvider)
          .set(KvKeys.dismissedUpdate, current.release.version.toString());
    }
    state = const UpdateIdle();
  }
}
