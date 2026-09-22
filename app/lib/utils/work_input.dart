import 'package:intl/intl.dart';

/// Reads `90`, `1h 30`, `1h30`, `1:30`, `2h` or `45m` as whole minutes.
///
/// Returns null for anything it cannot read, so a slip leaves whatever
/// was stored alone rather than overwriting it with a zero nobody meant.
int? parseMinutes(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  final bare = RegExp(r'^\d+$').firstMatch(text);
  if (bare != null) return int.tryParse(text);

  final colon = RegExp(r'^(\d+):([0-5]?\d)$').firstMatch(text);
  if (colon != null) {
    final hours = int.tryParse(colon.group(1)!);
    final minutes = int.tryParse(colon.group(2)!);
    if (hours == null || minutes == null) return null;
    return _hoursAndMinutes(hours, minutes);
  }

  final parts = RegExp(r'^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m?)?$').firstMatch(text);
  if (parts == null) return null;
  final hoursText = parts.group(1);
  final minutesText = parts.group(2);
  if (hoursText == null && minutesText == null) return null;
  final hours = hoursText == null ? 0 : int.tryParse(hoursText);
  final minutes = minutesText == null ? 0 : int.tryParse(minutesText);
  if (hours == null || minutes == null) return null;
  return _hoursAndMinutes(hours, minutes);
}

/// The largest total these guards accept: not `int`'s own maximum, but the
/// largest integer that is exact on every target this app builds for.
///
/// This app compiles to JavaScript as well as native (nemo ships a web
/// build), and dart2js represents Dart's `int` as a JS `number` -- a
/// double, exact only up to 2^53 - 1. `int`'s own maximum
/// (9223372036854775807) compiles fine natively, but a ceiling the web
/// compiler cannot represent exactly is not a ceiling at all: values past
/// this point would compile to a *different*, rounded number on web than
/// on native. So the ceiling is 2^53 - 1 (`9007199254740991`) everywhere,
/// even though native `int` could hold far more -- amounts and durations
/// beyond it are absurd inputs anyway, and refusing them is the documented
/// contract above ("anything it cannot represent exactly returns null").
const int _maxExactInt = 9007199254740991;

int? _hoursAndMinutes(int hours, int minutes) {
  if (hours > (_maxExactInt - minutes) ~/ 60) return null;
  return hours * 60 + minutes;
}

/// Reads an amount written the way [locale] writes one -- `12.50` or
/// `12,50` -- as minor units, so 12.50 euro is 1250.
///
/// Returns null for anything it cannot read, and for more decimal places
/// than the minor unit has: 12.505 is a typo, not an amount.
///
/// The digits are parsed and combined as integers, never as a `double` --
/// a double loses precision past 2^53 - 1, and rounding an already-lossy
/// intermediate can silently hand back an amount nobody typed. Computing
/// the minor units from the digit strings themselves is exact by
/// construction for every input the regex above admits, so there is no
/// imprecise intermediate left to bound.
int? parseMinorUnits(String input, {required String locale}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  final normalised = text.replaceAll(separator, '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalised)) return null;
  final segments = normalised.split('.');
  final whole = int.tryParse(segments[0]);
  if (whole == null) return null;
  var fractionText = segments.length > 1 ? segments[1] : '0';
  if (fractionText.length == 1) fractionText = '${fractionText}0';
  final fraction = int.tryParse(fractionText);
  if (fraction == null) return null;
  return _wholeAndFraction(whole, fraction);
}

/// Dart's `int` is a fixed-size 64-bit integer, so [int.tryParse] already
/// refuses a digit run too long to hold -- but `whole * 100 + fraction` can
/// still overflow (and silently wrap, not throw) even when both parsed
/// cleanly on their own. This refuses that case too instead of returning a
/// wrapped, wrong total -- the same guard [_hoursAndMinutes] uses above,
/// against the same [_maxExactInt] ceiling.
int? _wholeAndFraction(int whole, int fraction) {
  if (whole > (_maxExactInt - fraction) ~/ 100) return null;
  return whole * 100 + fraction;
}

/// `1 h 30 min`, `45 min`, `2 h`. Labels come from the l10n catalogue so
/// each language writes its own.
String formatMinutes(
  int minutes, {
  required String hoursLabel,
  required String minutesLabel,
}) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest $minutesLabel';
  if (rest == 0) return '$hours $hoursLabel';
  return '$hours $hoursLabel $rest $minutesLabel';
}

/// The amount as [locale] would write it, with [currency]'s symbol.
String formatMoney(
  int minor, {
  required String currency,
  required String locale,
}) => NumberFormat.simpleCurrency(
  locale: locale,
  name: currency,
).format(minor / 100);
