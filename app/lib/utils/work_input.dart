import 'package:intl/intl.dart';

/// Reads `90`, `1h 30`, `1h30`, `1:30`, `2h` or `45m` as whole minutes.
///
/// Returns null for anything it cannot read, so a slip leaves whatever
/// was stored alone rather than overwriting it with a zero nobody meant.
int? parseMinutes(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  final bare = RegExp(r'^\d+$').firstMatch(text);
  if (bare != null) return int.parse(text);

  final colon = RegExp(r'^(\d+):([0-5]?\d)$').firstMatch(text);
  if (colon != null) {
    return int.parse(colon.group(1)!) * 60 + int.parse(colon.group(2)!);
  }

  final parts = RegExp(r'^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m?)?$').firstMatch(text);
  if (parts == null) return null;
  final hours = parts.group(1);
  final minutes = parts.group(2);
  if (hours == null && minutes == null) return null;
  final total =
      (hours == null ? 0 : int.parse(hours) * 60) +
      (minutes == null ? 0 : int.parse(minutes));
  return total;
}

/// Reads an amount written the way [locale] writes one -- `12.50` or
/// `12,50` -- as minor units, so 12.50 euro is 1250.
///
/// Returns null for anything it cannot read, and for more decimal places
/// than the minor unit has: 12.505 is a typo, not an amount.
int? parseMinorUnits(String input, {required String locale}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  final normalised = text.replaceAll(separator, '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalised)) return null;
  final value = double.parse(normalised);
  return (value * 100).round();
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
