import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Fan-out of "something changed" pokes to connected clients, as raw
/// server-sent-event frames.
class EventHub {
  EventHub({this.heartbeat = const Duration(seconds: 25)});

  static const connectedFrame = ': connected\n\n';
  static const changedFrame = 'event: changed\ndata: {}\n\n';
  static const pingFrame = ': ping\n\n';

  final Duration heartbeat;
  final _connections = <String, Set<StreamController<String>>>{};

  int get connections =>
      _connections.values.fold(0, (sum, set) => sum + set.length);

  Stream<String> subscribe(String userId) {
    late final StreamController<String> controller;
    Timer? timer;
    controller = StreamController<String>(
      onListen: () {
        _connections.putIfAbsent(userId, () => {}).add(controller);
        controller.add(connectedFrame);
        timer = Timer.periodic(heartbeat, (_) => controller.add(pingFrame));
      },
      onCancel: () {
        timer?.cancel();
        final set = _connections[userId];
        set?.remove(controller);
        if (set != null && set.isEmpty) _connections.remove(userId);
        // Not awaited: close() completes only after this cancel finishes.
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  void notify(Iterable<String> userIds) {
    for (final id in userIds.toSet()) {
      for (final c in _connections[id] ?? const <StreamController<String>>{}) {
        c.add(changedFrame);
      }
    }
  }

  Future<void> close() async {
    final all = _connections.values.expand((s) => s.toList()).toList();
    _connections.clear();
    for (final c in all) {
      unawaited(c.close());
    }
  }
}

/// Streams [userId]'s events as `text/event-stream`.
Response sseResponse(EventHub hub, String userId) => Response.ok(
  hub.subscribe(userId).transform(utf8.encoder),
  headers: const {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-cache',
    'x-accel-buffering': 'no',
  },
  context: const {'shelf.io.buffer_output': false},
);
