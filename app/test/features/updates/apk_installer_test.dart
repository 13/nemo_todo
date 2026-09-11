import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  late File apk;

  setUp(() {
    apk = File('${Directory.systemTemp.createTempSync('nemo-apk').path}/n.apk')
      ..writeAsStringSync('not really an apk');
  });
  tearDown(() => apk.parent.deleteSync(recursive: true));

  test('hands the path to the system and reports acceptance', () async {
    final opened = <String>[];
    final installer = SystemApkInstaller(
      open: (path) async {
        opened.add(path);
        return OpenResult();
      },
    );
    expect(await installer.install(apk), isTrue);
    expect(opened, [apk.path]);
  });

  test('reports a refusal rather than pretending it worked', () async {
    final installer = SystemApkInstaller(
      open: (_) async =>
          OpenResult(type: ResultType.permissionDenied, message: 'no'),
    );
    expect(await installer.install(apk), isFalse);
  });

  test('a missing file never reaches the system', () async {
    var called = false;
    final installer = SystemApkInstaller(
      open: (_) async {
        called = true;
        return OpenResult();
      },
    );
    apk.deleteSync();
    expect(await installer.install(apk), isFalse);
    expect(called, isFalse);
  });

  test('the unsupported installer does nothing', () async {
    expect(await const UnsupportedApkInstaller().install(apk), isFalse);
  });
}
