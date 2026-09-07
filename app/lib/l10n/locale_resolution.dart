import 'package:flutter/widgets.dart';

/// English is the source catalogue and therefore always complete.
const fallbackLocale = Locale('en');

/// Exact language-and-region match, then language, then [fallbackLocale].
Locale resolveAppLocale(Locale? preferred, Iterable<Locale> supported) {
  if (preferred == null) return fallbackLocale;
  for (final locale in supported) {
    if (locale.languageCode == preferred.languageCode &&
        locale.countryCode == preferred.countryCode) {
      return locale;
    }
  }
  for (final locale in supported) {
    if (locale.languageCode == preferred.languageCode) return locale;
  }
  return fallbackLocale;
}
