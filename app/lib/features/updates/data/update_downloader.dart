import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an update into the app's own cache directory, which needs no
/// permission and gets cleaned up by Android under pressure.
class UpdateDownloader {
  UpdateDownloader(this._dio, {Future<Directory> Function()? directory})
    : _directory = directory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _directory;

  Future<File> download(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File('${(await _directory()).path}/${asset.name}');
    if (file.existsSync()) file.deleteSync();
    try {
      await _dio.download(
        asset.url,
        file.path,
        onReceiveProgress: (received, total) =>
            onProgress?.call(total <= 0 ? -1 : received / total),
      );
    } on Object {
      if (file.existsSync()) file.deleteSync();
      throw const UpdateException(UpdateFailure.network);
    }

    final expected = asset.sha256;
    if (expected != null) {
      final actual = sha256.convert(await file.readAsBytes()).toString();
      if (actual != expected.toLowerCase()) {
        file.deleteSync();
        throw const UpdateException(UpdateFailure.malformed);
      }
    }
    onProgress?.call(1);
    return file;
  }
}
