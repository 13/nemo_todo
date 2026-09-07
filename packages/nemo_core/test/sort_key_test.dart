import 'dart:math';

import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  test('first key is the middle of the alphabet', () {
    expect(SortKey.first(), 'V');
  });

  test('between orders strictly', () {
    final mid = SortKey.between('1', '2');
    expect(mid.compareTo('1'), greaterThan(0));
    expect(mid.compareTo('2'), lessThan(0));
  });

  test('before/after extend the ends', () {
    expect(SortKey.after('V').compareTo('V'), greaterThan(0));
    expect(SortKey.before('V').compareTo('V'), lessThan(0));
    expect(SortKey.after('z').compareTo('z'), greaterThan(0));
    expect(SortKey.before('0V').compareTo('0V'), lessThan(0));
  });

  test('keys never end in 0', () {
    expect(SortKey.between(null, '1'), isNot(endsWith('0')));
    expect(SortKey.between(null, '0X'), isNot(endsWith('0')));
    expect(SortKey.between('1z', '2'), isNot(endsWith('0')));
  });

  test('throws when before >= after', () {
    expect(() => SortKey.between('2', '1'), throwsArgumentError);
    expect(() => SortKey.between('1', '1'), throwsArgumentError);
  });

  test('random insertions keep a valid, bounded order', () {
    final rnd = Random(7);
    final keys = <String>[SortKey.first()];
    for (var i = 0; i < 500; i++) {
      final pos = rnd.nextInt(keys.length + 1);
      final before = pos == 0 ? null : keys[pos - 1];
      final after = pos == keys.length ? null : keys[pos];
      keys.insert(pos, SortKey.between(before, after));
    }
    final sorted = [...keys]..sort(SortKey.compare);
    expect(sorted, keys);
    expect(keys.toSet().length, keys.length);
    expect(keys.map((k) => k.length).reduce(max), lessThan(60));
    expect(keys.any((k) => k.endsWith('0')), isFalse);
  });

  test('appending 200 items keeps keys short', () {
    var key = SortKey.first();
    final seen = <String>[key];
    for (var i = 0; i < 200; i++) {
      key = SortKey.after(key);
      expect(key.compareTo(seen.last), greaterThan(0));
      seen.add(key);
    }
    expect(key.length, lessThan(10));
  });

  test('prepending 200 items keeps keys short', () {
    var key = SortKey.first();
    for (var i = 0; i < 200; i++) {
      final next = SortKey.before(key);
      expect(next.compareTo(key), lessThan(0));
      key = next;
    }
    expect(key.length, lessThan(10));
    expect(key, isNot(endsWith('0')));
  });
}
