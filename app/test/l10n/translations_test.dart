import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/l10n/locale_resolution.dart';

void main() {
  test('every catalogue has exactly the template keys', () {
    Set<String> keys(String file) {
      final json = jsonDecode(
        File('lib/l10n/$file').readAsStringSync(),
      ) as Map<String, dynamic>;
      return json.keys.where((k) => !k.startsWith('@')).toSet();
    }

    final en = keys('app_en.arb');
    expect(keys('app_de.arb'), en);
    expect(keys('app_it.arb'), en);
  });

  test('locale resolution prefers exact, then language, then English', () {
    expect(resolveAppLocale(null, L.supportedLocales), const Locale('en'));
    expect(
      resolveAppLocale(const Locale('de', 'AT'), L.supportedLocales),
      const Locale('de'),
    );
    expect(
      resolveAppLocale(const Locale('it'), L.supportedLocales),
      const Locale('it'),
    );
    expect(
      resolveAppLocale(const Locale('fr'), L.supportedLocales),
      const Locale('en'),
    );
  });

  test('German and Italian catalogues load', () async {
    expect((await L.delegate.load(const Locale('de'))).navToday, 'Heute');
    expect((await L.delegate.load(const Locale('it'))).navToday, 'Oggi');
  });
}
