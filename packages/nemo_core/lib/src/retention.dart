import 'package:nemo_core/src/hlc.dart';

/// How long a tombstone is kept: the app offers a deleted task back for
/// this long, and the server's purge never retires one sooner.
const tombstoneRetention = Duration(days: 30);

/// The stamp a tombstone must sort at or after to still be within
/// [retention] of [now].
///
/// Tombstones are HLC strings, and an HLC sorts as a string exactly as it
/// sorts as a time, so "deleted since" is a string comparison against a
/// stamp built for the cutoff instant.
String tombstoneCutoff(
  DateTime now, {
  Duration retention = tombstoneRetention,
}) => Hlc(
  millis: now.subtract(retention).millisecondsSinceEpoch,
  counter: 0,
  node: '',
).toString();

/// A deletion stamp older than any window: what "delete now" writes, so a
/// tombstone leaves every device's recently deleted at once and the next
/// purge retires it.
String erasedStamp(String node) =>
    Hlc(millis: 0, counter: 0, node: node).toString();
