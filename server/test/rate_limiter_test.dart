import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  late ServerDatabase db;

  setUp(() => db = ServerDatabase.memory());
  tearDown(() => db.close());

  test('allows max hits per window per key and frees afterwards', () async {
    var now = DateTime(2026);
    final limiter = RateLimiter(db, max: 3, now: () => now);
    expect(await limiter.allow('a'), isTrue);
    expect(await limiter.allow('a'), isTrue);
    expect(await limiter.allow('a'), isTrue);
    expect(await limiter.allow('a'), isFalse);
    expect(await limiter.allow('b'), isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(await limiter.allow('a'), isTrue);
  });

  test('a refused hit does not extend the wait', () async {
    var now = DateTime(2026);
    final limiter = RateLimiter(db, max: 1, now: () => now);
    expect(await limiter.allow('a'), isTrue);
    now = now.add(const Duration(seconds: 50));
    expect(await limiter.allow('a'), isFalse);
    now = now.add(const Duration(seconds: 10));
    expect(await limiter.allow('a'), isTrue);
  });

  test('the counts survive a restart', () async {
    var now = DateTime(2026);
    final before = RateLimiter(db, max: 3, now: () => now);
    for (var i = 0; i < 3; i++) {
      expect(await before.allow('a'), isTrue);
    }

    // A new limiter over the same database, as after the server restarts.
    now = now.add(const Duration(seconds: 5));
    final after = RateLimiter(db, max: 3, now: () => now);
    expect(
      await after.allow('a'),
      isFalse,
      reason: 'restarting the server must not buy another round of guesses',
    );
    expect(await after.allow('b'), isTrue);

    now = now.add(const Duration(minutes: 1));
    expect(await after.allow('a'), isTrue);
  });

  test('keys stop being tracked once their window has passed', () async {
    var now = DateTime(2026);
    final limiter = RateLimiter(db, max: 3, now: () => now);
    for (var i = 0; i < 1000; i++) {
      await limiter.allow('client-$i');
    }
    expect(await limiter.trackedKeys(), 1000);

    now = now.add(const Duration(minutes: 2));
    await limiter.allow('someone-else');
    expect(
      await limiter.trackedKeys(),
      lessThan(10),
      reason: 'a flood of one-off addresses must not be remembered forever',
    );
  });

  test('a flood cannot grow the table past the cap', () async {
    var now = DateTime(2026);
    final limiter = RateLimiter(db, max: 3, maxKeys: 50, now: () => now);
    for (var i = 0; i < 500; i++) {
      await limiter.allow('client-$i');
    }
    expect(await limiter.trackedKeys(), lessThanOrEqualTo(50));

    // Once the window passes the cap frees up again.
    now = now.add(const Duration(minutes: 2));
    expect(await limiter.allow('a-real-client'), isTrue);
  });

  test('concurrent hits for one key are counted one by one', () async {
    final now = DateTime(2026);
    final limiter = RateLimiter(db, max: 3, now: () => now);
    final results = await Future.wait([
      for (var i = 0; i < 10; i++) limiter.allow('a'),
    ]);
    expect(results.where((ok) => ok), hasLength(3));
  });
}
