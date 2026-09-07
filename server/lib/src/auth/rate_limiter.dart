/// Sliding-window counter: at most [max] hits per [window] for each key.
class RateLimiter {
  RateLimiter({
    this.max = 10,
    this.window = const Duration(minutes: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int max;
  final Duration window;
  final DateTime Function() _now;
  final _hits = <String, List<DateTime>>{};

  /// Records a hit for [key] and reports whether it is within the limit.
  bool allow(String key) {
    final now = _now();
    final hits = _hits.putIfAbsent(key, () => [])
      ..removeWhere((t) => now.difference(t) >= window);
    if (hits.length >= max) return false;
    hits.add(now);
    return true;
  }
}
