import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Opens an APK so Android can install it.
abstract interface class ApkInstaller {
  /// True when the system accepted the request. Whether the user then
  /// confirms the install is Android's business, not ours.
  Future<bool> install(File apk);
}

class SystemApkInstaller implements ApkInstaller {
  SystemApkInstaller({Future<OpenResult> Function(String path)? open})
    : _open = open ?? OpenFilex.open;

  final Future<OpenResult> Function(String path) _open;

  @override
  Future<bool> install(File apk) async {
    if (!apk.existsSync()) return false;
    final result = await _open(apk.path);
    return result.type == ResultType.done;
  }
}

/// Everywhere that cannot install an APK, which is everywhere but Android.
class UnsupportedApkInstaller implements ApkInstaller {
  const UnsupportedApkInstaller();

  @override
  Future<bool> install(File apk) async => false;
}
