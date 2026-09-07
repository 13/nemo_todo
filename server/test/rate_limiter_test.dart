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
}
