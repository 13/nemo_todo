import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  group('Hlc', () {
    test('formats fixed width and round-trips', () {
      const h = Hlc(millis: 1725700000000, counter: 10, node: 'n1');
      expect(h.toString(), '1725700000000-000a-n1');
      expect(Hlc.parse(h.toString()), h);
    });

    test('rejects malformed strings', () {
      expect(() => Hlc.parse('nope'), throwsFormatException);
      expect(() => Hlc.parse('1725700000000-000a-'), throwsFormatException);
    });

    test('string order equals logical order', () {
      const a = Hlc(millis: 1, counter: 5, node: 'b');
      const b = Hlc(millis: 2, counter: 0, node: 'a');
      const c = Hlc(millis: 2, counter: 0, node: 'b');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(c), lessThan(0));
      expect(a < b, isTrue);
      expect(c > b, isTrue);
      expect(a.toString().compareTo(b.toString()), lessThan(0));
    });
  });

  group('HlcClock', () {
    test('now is strictly monotonic within one millisecond', () {
      final clock = HlcClock(
        node: 'n',
        now: () => DateTime.fromMillisecondsSinceEpoch(100),
      );
      final a = clock.now();
      final b = clock.now();
      expect(a.millis, 100);
      expect(b.counter, a.counter + 1);
      expect(b.compareTo(a), greaterThan(0));
      expect(clock.last, b);
    });

    test('now never goes backwards when the wall clock does', () {
      var wall = 200;
      final clock = HlcClock(
        node: 'n',
        now: () => DateTime.fromMillisecondsSinceEpoch(wall),
      );
      final a = clock.now();
      wall = 150;
      final b = clock.now();
      expect(b.millis, a.millis);
      expect(b.counter, a.counter + 1);
    });

    test('receive adopts a remote clock that is ahead', () {
      final clock = HlcClock(
        node: 'n',
        now: () => DateTime.fromMillisecondsSinceEpoch(100),
      );
      final r = clock.receive(
        const Hlc(millis: 500, counter: 3, node: 'other'),
      );
      expect(r.millis, 500);
      expect(r.counter, 4);
      expect(r.node, 'n');
      expect(clock.now().compareTo(r), greaterThan(0));
    });

    test('receive ignores a remote clock that is behind', () {
      final clock = HlcClock(
        node: 'n',
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final r = clock.receive(
        const Hlc(millis: 500, counter: 3, node: 'other'),
      );
      expect(r.millis, 1000);
      expect(r.counter, 0);
    });

    test('receive with equal millis on both sides takes the max counter', () {
      final clock = HlcClock(
        node: 'n',
        now: () => DateTime.fromMillisecondsSinceEpoch(100),
        last: const Hlc(millis: 100, counter: 7, node: 'n'),
      );
      final r = clock.receive(
        const Hlc(millis: 100, counter: 3, node: 'other'),
      );
      expect(r.counter, 8);
    });
  });
}
