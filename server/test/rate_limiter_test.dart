import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  test('allows max hits per window per key and frees afterwards', () {
    var now = DateTime(2026);
    final limiter = RateLimiter(max: 3, now: () => now);
    expect(limiter.allow('a'), isTrue);
    expect(limiter.allow('a'), isTrue);
    expect(limiter.allow('a'), isTrue);
    expect(limiter.allow('a'), isFalse);
    expect(limiter.allow('b'), isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(limiter.allow('a'), isTrue);
  });

  test('keys stop being tracked once their window has passed', () {
    var now = DateTime(2026);
    final limiter = RateLimiter(max: 3, now: () => now);
    for (var i = 0; i < 1000; i++) {
      limiter.allow('client-$i');
    }
    expect(limiter.trackedKeys, 1000);

    now = now.add(const Duration(minutes: 2));
    limiter.allow('someone-else');
    expect(
      limiter.trackedKeys,
      lessThan(10),
      reason: 'a flood of one-off addresses must not be remembered forever',
    );
  });

  test('a flood cannot grow the map past the cap', () {
    var now = DateTime(2026);
    final limiter = RateLimiter(max: 3, maxKeys: 50, now: () => now);
    for (var i = 0; i < 500; i++) {
      limiter.allow('client-$i');
    }
    expect(limiter.trackedKeys, lessThanOrEqualTo(50));

    // Once the window passes the cap frees up again.
    now = now.add(const Duration(minutes: 2));
    expect(limiter.allow('a-real-client'), isTrue);
  });
}
