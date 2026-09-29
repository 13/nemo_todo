import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:nemo_server/src/db/server_database.dart';

/// Sliding-window counter: at most [max] hits per [window] for each key.
///
/// The hits live in the database rather than in memory, so a restart does
/// not start everyone's count over: a guesser who can crash or outlast the
/// server does not get a fresh allowance for it.
class RateLimiter {
  RateLimiter(
    this._db, {
    this.max = 10,
    this.window = const Duration(minutes: 1),
    this.maxKeys = 10000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _lastSweep = (now ?? DateTime.now)();

  final ServerDatabase _db;
  final int max;
  final Duration window;

  /// Ceiling on the number of keys held at once. Keys are addresses a
  /// caller supplies, so without a ceiling a flood from many addresses is
  /// a table that only grows. At the ceiling an unknown key is refused
  /// rather than admitted: the cost of a flood is then 429s on the auth
  /// endpoints, which is the lesser of the two failures.
  final int maxKeys;

  final DateTime Function() _now;
  DateTime _lastSweep;

  /// How many keys have hits on record, counted or not yet swept.
  @visibleForTesting
  Future<int> trackedKeys() => _keyCount();

  /// Records a hit for [key] and reports whether it is within the limit.
  ///
  /// A refused hit is not recorded, so hammering away while refused does
  /// not push back the moment the key is let in again.
  Future<bool> allow(String key) {
    final now = _now();
    final nowMillis = now.millisecondsSinceEpoch;
    // One transaction, so two requests arriving together cannot both read
    // a count of max - 1 and both be let in.
    return _db.transaction(() async {
      await _sweep(now);
      final hits = _db.rateLimitHits;
      final known = await _count(hits.clientKey.equals(key));
      if (known == 0 && await _keyCount() >= maxKeys) return false;
      await (_db.delete(hits)..where(
            (t) =>
                t.clientKey.equals(key) &
                t.expiresAt.isSmallerOrEqualValue(nowMillis),
          ))
          .go();
      final live = await _count(
        hits.clientKey.equals(key) &
            hits.expiresAt.isBiggerThanValue(nowMillis),
      );
      if (live >= max) return false;
      await _db
          .into(hits)
          .insert(
            RateLimitHitsCompanion.insert(
              clientKey: key,
              expiresAt: now.add(window).millisecondsSinceEpoch,
            ),
          );
      return true;
    });
  }

  Future<int> _count(Expression<bool> where) async {
    final hits = _db.rateLimitHits;
    final count = hits.id.count();
    final query = _db.selectOnly(hits)
      ..addColumns([count])
      ..where(where);
    final row = await query.getSingle();
    return row.read<int>(count) ?? 0;
  }

  Future<int> _keyCount() async {
    final hits = _db.rateLimitHits;
    final count = hits.clientKey.count(distinct: true);
    final query = _db.selectOnly(hits)..addColumns([count]);
    final row = await query.getSingle();
    return row.read<int>(count) ?? 0;
  }

  /// Drops hits that have aged out. Runs at most once per window, so the
  /// cost is amortised over the requests of that window.
  Future<void> _sweep(DateTime now) async {
    if (now.difference(_lastSweep) < window) return;
    _lastSweep = now;
    await deleteExpiredHits(_db, now);
  }

  /// Deletes every hit that no longer counts, for [RateLimiter]s of any
  /// window, and returns how many went.
  ///
  /// The limiter sweeps as it goes; this is for housekeeping to catch what
  /// a server that stopped before its next sweep left behind.
  static Future<int> deleteExpiredHits(ServerDatabase db, DateTime now) =>
      (db.delete(db.rateLimitHits)..where(
            (t) =>
                t.expiresAt.isSmallerOrEqualValue(now.millisecondsSinceEpoch),
          ))
          .go();
}
