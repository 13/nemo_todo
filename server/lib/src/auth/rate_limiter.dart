import 'package:meta/meta.dart';

/// Sliding-window counter: at most [max] hits per [window] for each key.
class RateLimiter {
  RateLimiter({
    this.max = 10,
    this.window = const Duration(minutes: 1),
    this.maxKeys = 10000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _lastSweep = (now ?? DateTime.now)();

  final int max;
  final Duration window;

  /// Ceiling on the number of keys held at once. Keys are addresses a
  /// caller supplies, so without a ceiling a flood from many addresses is
  /// a memory leak. At the ceiling an unknown key is refused rather than
  /// admitted: the cost of a flood is then 429s on the auth endpoints,
  /// which is the lesser of the two failures.
  final int maxKeys;

  final DateTime Function() _now;
  final _hits = <String, List<DateTime>>{};
  DateTime _lastSweep;

  @visibleForTesting
  int get trackedKeys => _hits.length;

  /// Records a hit for [key] and reports whether it is within the limit.
  bool allow(String key) {
    final now = _now();
    _sweep(now);
    final existing = _hits[key];
    if (existing == null && _hits.length >= maxKeys) return false;
    final hits = existing ?? (_hits[key] = [])
      ..removeWhere((t) => now.difference(t) >= window);
    if (hits.length >= max) return false;
    hits.add(now);
    return true;
  }

  /// Drops keys whose hits have all aged out. Runs at most once per window,
  /// so the cost is amortised over the requests of that window.
  void _sweep(DateTime now) {
    if (now.difference(_lastSweep) < window) return;
    _lastSweep = now;
    _hits.removeWhere((_, hits) {
      hits.removeWhere((t) => now.difference(t) >= window);
      return hits.isEmpty;
    });
  }
}
