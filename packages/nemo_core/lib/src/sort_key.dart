/// Fractional-index sort keys.
///
/// Keys are plain strings over `0-9A-Za-z` compared as strings. A key that
/// sorts strictly between any two others always exists, so moving an item
/// never renumbers its neighbours. Generated keys never end in `0`, because
/// nothing fits between `'1'` and `'10'`.
abstract final class SortKey {
  static const _alphabet =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const _base = 62;

  static int compare(String a, String b) => a.compareTo(b);

  /// The key for the first item of an empty sequence.
  static String first() => between(null, null);

  /// A key that sorts after [key].
  static String after(String key) => between(key, null);

  /// A key that sorts before [key].
  static String before(String key) => between(null, key);

  /// A key strictly between [before] and [after]; `null` means unbounded.
  static String between(String? before, String? after) {
    final a = before ?? '';
    final b = after ?? '';
    if (b.isNotEmpty && a.compareTo(b) >= 0) {
      throw ArgumentError('before ($a) must sort before after ($b)');
    }
    return _mid(a, b);
  }

  static int _digit(String ch) => _alphabet.indexOf(ch);

  static String _char(int d) => _alphabet[d];

  /// Midpoint between [a] and [b], where an empty [b] means "unbounded".
  static String _mid(String a, String b) {
    var n = 0;
    while (n < a.length && n < b.length && a[n] == b[n]) {
      n++;
    }
    if (n > 0) {
      return a.substring(0, n) + _mid(a.substring(n), b.substring(n));
    }
    final da = a.isEmpty ? 0 : _digit(a[0]);
    final db = b.isEmpty ? _base : _digit(b[0]);
    // Against an open end, step by one digit instead of halving so that
    // repeated appends (or prepends) use the whole alphabet before the key
    // grows by a character.
    if (b.isEmpty && a.isNotEmpty && da < _base - 1) return _char(da + 1);
    if (a.isEmpty && b.isNotEmpty && db > 1) return _char(db - 1);
    if (db - da > 1) return _char((da + db) ~/ 2);
    if (a.isEmpty) return _char(da) + _mid('', b.substring(1));
    return a[0] + _mid(a.substring(1), '');
  }
}
