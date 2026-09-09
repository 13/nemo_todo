import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/sync/data/sse_client.dart';

/// Hands back a stream the test writes frames into, byte by byte if it
/// likes, so a frame can be split exactly where a network would split it.
/// Every connection gets its own, the way a reconnect gets a new one.
class _FakeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final connections = <StreamController<Uint8List>>[];

  StreamController<Uint8List> get current => connections.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final controller = StreamController<Uint8List>();
    connections.add(controller);
    return ResponseBody(
      controller.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    for (final c in connections) {
      if (!c.isClosed) unawaited(c.close());
    }
  }
}

void main() {
  group('eventsIn', () {
    test('reads event names out of complete frames', () {
      expect(SseClient.eventsIn(': connected\n\n').events, isEmpty);
      expect(SseClient.eventsIn('event: changed\ndata: {}\n\n').events, [
        'changed',
      ]);
      expect(
        SseClient.eventsIn(
          'event: changed\ndata: {}\n\n: ping\n\nevent: changed\ndata: {}\n\n',
        ).events,
        ['changed', 'changed'],
      );
    });

    test('holds an unterminated frame back instead of reading it', () {
      final partial = SseClient.eventsIn('event: chan');
      expect(partial.events, isEmpty);
      expect(partial.rest, 'event: chan');

      final rest = SseClient.eventsIn('${partial.rest}ged\ndata: {}\n\n');
      expect(rest.events, ['changed']);
      expect(rest.rest, isEmpty);
    });
  });

  group('SseClient', () {
    late _FakeAdapter adapter;
    late Dio dio;
    late int changes;
    late SseClient client;

    setUp(() {
      adapter = _FakeAdapter();
      dio = Dio()..httpClientAdapter = adapter;
      changes = 0;
      client = SseClient(
        dio,
        baseUrl: 'https://nemo.test',
        token: 'tok',
        onChanged: () => changes++,
        initialBackoff: const Duration(milliseconds: 1),
      );
    });

    tearDown(() {
      client.stop();
      adapter.close();
    });

    /// Waits for something to have happened, rather than for a fixed number
    /// of milliseconds. The client's work is a request and a decoder turn,
    /// and a machine running the whole suite at once takes longer over
    /// those than one running this file alone -- which is how a fixed wait
    /// here turns into a test that fails once a fortnight for no reason.
    Future<void> waitFor(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!done() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }

    /// For the assertions that nothing happens, where there is no condition
    /// to wait for. Generous, because it only costs time when it passes.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    Future<void> send(String text) async {
      adapter.current.add(Uint8List.fromList(utf8.encode(text)));
    }

    test('syncs once on connect, then on every changed frame', () async {
      client.start();
      await waitFor(() => changes >= 1);
      expect(changes, 1, reason: 'a reconnect may have missed events');
      expect(adapter.requests.single.uri.toString(), contains('token=tok'));

      await send(EventHubFrames.connected);
      await settle();
      expect(changes, 1);

      await send(EventHubFrames.changed);
      await waitFor(() => changes >= 2);
      expect(changes, 2);

      await send(EventHubFrames.ping);
      await settle();
      expect(changes, 2);
    });

    // The bug this pins: a frame arriving in two reads used to be parsed
    // twice as nonsense and dropped, so the app sat on stale data until
    // something else happened to sync it.
    test('reads a frame split across two reads', () async {
      client.start();
      await waitFor(() => changes >= 1);
      changes = 0;

      await send('event: chan');
      await settle();
      expect(changes, 0, reason: 'half a frame is not an event');

      await send('ged\ndata: {}\n\n');
      await waitFor(() => changes >= 1);
      expect(changes, 1);
    });

    test('reads a frame split inside a multi-byte character', () async {
      client.start();
      await waitFor(() => changes >= 1);
      changes = 0;

      final bytes = utf8.encode('event: changed\ndata: {"who":"Anné"}\n\n');
      final split = bytes.length - 6;
      adapter.current
        ..add(Uint8List.fromList(bytes.sublist(0, split)))
        ..add(Uint8List.fromList(bytes.sublist(split)));
      await waitFor(() => changes >= 1);

      expect(changes, 1);
    });

    test('reconnects after the stream ends', () async {
      client.start();
      await waitFor(() => changes >= 1);
      expect(changes, 1);

      await adapter.current.close();
      await waitFor(() => adapter.requests.length >= 2);

      expect(adapter.requests, hasLength(2));
      expect(changes, 2, reason: 'a fresh connection syncs');
    });

    test('stop ends the stream and stops reconnecting', () async {
      client.start();
      await waitFor(() => adapter.requests.isNotEmpty);
      client.stop();

      await adapter.current.close();
      await settle();

      expect(adapter.requests, hasLength(1));
      expect(client.connected, isFalse);
    });
  });
}

/// The frames the server actually sends, copied from `EventHub` on the
/// server side, which the app cannot import.
abstract final class EventHubFrames {
  static const connected = ': connected\n\n';
  static const changed = 'event: changed\ndata: {}\n\n';
  static const ping = ': ping\n\n';
}
