import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Hybrid logical clock timestamp.
///
/// Serialised as `"{millis 13 digits}-{counter 4 hex}-{node}"`, which sorts
/// as a plain string in the same order as [compareTo]. The node id makes two
/// stamps from different devices never compare equal.
@immutable
class Hlc implements Comparable<Hlc> {
  const Hlc({required this.millis, required this.counter, required this.node});

  factory Hlc.parse(String value) {
    final first = value.indexOf('-');
    final second = value.indexOf('-', first + 1);
    if (first != 13 || second != 18 || second + 1 >= value.length) {
      throw FormatException('Not an HLC string', value);
    }
    return Hlc(
      millis: int.parse(value.substring(0, first)),
      counter: int.parse(value.substring(first + 1, second), radix: 16),
      node: value.substring(second + 1),
    );
  }

  /// Wall-clock milliseconds since the Unix epoch.
  final int millis;

  /// Disambiguates stamps issued within the same millisecond.
  final int counter;

  /// Identifies the device that issued the stamp.
  final String node;

  @override
  int compareTo(Hlc other) => toString().compareTo(other.toString());

  bool operator <(Hlc other) => compareTo(other) < 0;

  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  String toString() =>
      '${millis.toString().padLeft(13, '0')}-'
      '${counter.toRadixString(16).padLeft(4, '0')}-$node';

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);
}

/// Issues strictly increasing [Hlc] stamps for one node and folds in stamps
/// received from other nodes so local time never falls behind them.
class HlcClock {
  HlcClock({required this.node, DateTime Function()? now, Hlc? last})
    : _now = now ?? DateTime.now,
      _last = last ?? Hlc(millis: 0, counter: 0, node: node);

  final String node;
  final DateTime Function() _now;
  Hlc _last;

  /// The most recent stamp issued or received.
  Hlc get last => _last;

  /// A new stamp greater than every stamp this clock has seen.
  Hlc now() {
    final wall = math.max(_now().millisecondsSinceEpoch, _last.millis);
    final counter = wall == _last.millis ? _last.counter + 1 : 0;
    return _last = Hlc(millis: wall, counter: counter, node: node);
  }

  /// Advances the clock past [remote] and returns the new local stamp.
  Hlc receive(Hlc remote) {
    final wallNow = _now().millisecondsSinceEpoch;
    final wall = math.max(wallNow, math.max(_last.millis, remote.millis));
    final int counter;
    if (wall == _last.millis && wall == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (wall == _last.millis) {
      counter = _last.counter + 1;
    } else if (wall == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    return _last = Hlc(millis: wall, counter: counter, node: node);
  }
}
