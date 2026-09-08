import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Holds a server-sent-events stream open and calls [onChanged] whenever the
/// server says something in one of our lists moved.
///
/// The stream is only a poke: the actual rows arrive through a normal sync.
/// Reconnects with exponential backoff, and a fresh connection also triggers
/// [onChanged] so anything missed while disconnected is picked up.
class SseClient {
  SseClient(
    this._dio, {
    required this.baseUrl,
    required this.token,
    required this.onChanged,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 60),
  });

  final Dio _dio;
  final String baseUrl;
  final String token;
  final void Function() onChanged;
  final Duration initialBackoff;
  final Duration maxBackoff;

  StreamSubscription<String>? _subscription;
  Timer? _retry;
  Duration _backoff = Duration.zero;
  var _stopped = true;

  /// The tail of the last chunk, when it ended mid-frame.
  var _pending = '';

  /// Ceiling on that tail. The server sends three short frames and nothing
  /// else, so a stream that never completes one is not a stream of ours,
  /// and holding on to it would be holding on to memory for ever.
  static const int _maxPending = 64 * 1024;

  bool get connected => _subscription != null;

  /// Splits [chunk] into complete frames, reports the event names in them,
  /// and hands back whatever followed the last blank line.
  ///
  /// A frame ends at a blank line, and nothing says one arrives whole: a
  /// `changed` frame can be split across two reads, and reading each read
  /// on its own would drop it. So the tail comes back to be prepended to
  /// the next chunk rather than parsed here.
  static ({List<String> events, String rest}) eventsIn(String chunk) {
    final frames = chunk.split('\n\n');
    final rest = frames.removeLast();
    return (
      events: [
        for (final frame in frames)
          for (final line in frame.split('\n'))
            if (line.startsWith('event:')) line.substring(6).trim(),
      ],
      rest: rest,
    );
  }

  void start() {
    if (!_stopped) return;
    _stopped = false;
    _backoff = initialBackoff;
    unawaited(_connect());
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _retry = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pending = '';
  }

  Future<void> _connect() async {
    if (_stopped) return;
    try {
      final response = await _dio.getUri<ResponseBody>(
        Uri.parse('$baseUrl/api/v1/events?token=$token'),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'accept': 'text/event-stream'},
        ),
      );
      if (_stopped) return;
      _backoff = initialBackoff;
      _pending = '';
      // A reconnect may have missed events; sync once on connect.
      onChanged();
      // Decoded by the stream rather than per chunk: a character can be
      // split across two reads just as a frame can, and decoding each read
      // on its own would mangle it.
      _subscription = utf8.decoder
          .bind(response.data!.stream)
          .listen(
            (text) {
              final parsed = eventsIn(_pending + text);
              _pending = parsed.rest.length > _maxPending ? '' : parsed.rest;
              if (parsed.events.contains('changed')) onChanged();
            },
            onDone: _scheduleRetry,
            onError: (Object _) => _scheduleRetry(),
            cancelOnError: true,
          );
    } on Object {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _subscription = null;
    if (_stopped) return;
    _retry?.cancel();
    _retry = Timer(_backoff, _connect);
    final next = _backoff * 2;
    _backoff = next > maxBackoff ? maxBackoff : next;
  }
}
