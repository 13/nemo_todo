import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// What the app is called wherever it names itself. The launcher label, the
/// web app manifest, the page head and the in-app strings are read by
/// different platforms, so this test keeps them saying the same thing.
const appTitle = 'nemo todo';

void main() {
  test('every language calls the app $appTitle', () async {
    for (final locale in L.supportedLocales) {
      final l = await L.delegate.load(locale);
      expect(l.appName, appTitle, reason: '$locale');
    }
  });

  test('the Android launcher label is $appTitle', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:label="$appTitle"'));
  });

  test('the web app manifest names the app $appTitle', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['name'], appTitle);
    expect(manifest['short_name'], appTitle);
  });

  test('the web page is titled $appTitle', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('<title>$appTitle</title>'));
    expect(
      html,
      contains('<meta name="apple-mobile-web-app-title" content="$appTitle">'),
    );
  });
}
