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
}
