import 'dart:async';

import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  test('notify reaches every connection of the named users only', () async {
    final hub = EventHub(heartbeat: const Duration(hours: 1));
    final a1 = <String>[];
    final a2 = <String>[];
    final b = <String>[];
    final subs = [
      hub.subscribe('a').listen(a1.add),
      hub.subscribe('a').listen(a2.add),
      hub.subscribe('b').listen(b.add),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(hub.connections, 3);
    hub.notify(['a', 'a', 'missing']);
    await Future<void>.delayed(Duration.zero);
    expect(a1, [EventHub.connectedFrame, EventHub.changedFrame]);
    expect(a2, [EventHub.connectedFrame, EventHub.changedFrame]);
    expect(b, [EventHub.connectedFrame]);
    await subs[0].cancel();
    expect(hub.connections, 2);
    await hub.close();
    expect(hub.connections, 0);
  });

  test('heartbeat frames keep flowing', () async {
    final hub = EventHub(heartbeat: const Duration(milliseconds: 10));
    final frames = await hub.subscribe('a').take(3).toList();
    expect(frames, [
      EventHub.connectedFrame,
      EventHub.pingFrame,
      EventHub.pingFrame,
    ]);
    await hub.close();
  });

  test('sse response opts out of every layer that would buffer it', () async {
    final hub = EventHub(heartbeat: const Duration(hours: 1));
    final response = sseResponse(hub, 'a');

    expect(response.headers['content-type'], 'text/event-stream; charset=utf-8');
    // nginx buffers proxied responses by default and holds frames back until a
    // buffer fills, which stalls sync behind a reverse proxy. This header is
    // what disables that for this response, so it is not a decoration.
    expect(response.headers['x-accel-buffering'], 'no');
    expect(response.headers['cache-control'], 'no-cache');
    // shelf's own output buffering would delay frames the same way.
    expect(response.context['shelf.io.buffer_output'], false);

    await hub.close();
  });
}
