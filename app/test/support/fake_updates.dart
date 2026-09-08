import 'dart:io';

import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

AppRelease releaseFixture({
  AppVersion version = const AppVersion(0, 2, 0),
  String notes = '- Faster search',
}) => AppRelease(
  version: version,
  tag: 'v$version',
  notes: notes,
  assets: [
    ReleaseAsset(
      name: 'nemo-$version+2-arm64-v8a.apk',
      url: 'https://example.test/arm64.apk',
      size: 24000000,
      sha256: 'abc123',
    ),
  ],
);

class FakeReleaseClient implements GithubReleaseClient {
  FakeReleaseClient({this.release, this.failure});

  AppRelease? release;
  UpdateFailure? failure;
  int calls = 0;

  @override
  String get repository => 'fake/repo';

  @override
  Future<AppRelease> latest() async {
    calls++;
    final f = failure;
    if (f != null) throw UpdateException(f);
    return release ?? releaseFixture();
  }
}

class FakeDownloader implements UpdateDownloader {
  FakeDownloader(this.file, {this.failure});

  final File file;
  UpdateFailure? failure;
  final progress = <double>[];

  @override
  Future<File> download(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final f = failure;
    if (f != null) throw UpdateException(f);
    for (final p in [0.5, 1.0]) {
      progress.add(p);
      onProgress?.call(p);
    }
    return file;
  }
}

class FakeInstaller implements ApkInstaller {
  final installed = <String>[];
  bool accepts = true;

  @override
  Future<bool> install(File apk) async {
    installed.add(apk.path);
    return accepts;
  }
}
