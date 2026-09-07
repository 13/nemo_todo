import 'dart:async';

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

  StreamSubscription<List<int>>? _subscription;
  Timer? _retry;
  Duration _backoff = Duration.zero;
  var _stopped = true;

  bool get connected => _subscription != null;

  /// Splits an SSE chunk into complete frames and reports the event names.
  static Iterable<String> eventsIn(String chunk) sync* {
    for (final frame in chunk.split('\n\n')) {
      for (final line in frame.split('\n')) {
        if (line.startsWith('event:')) yield line.substring(6).trim();
      }
    }
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
      // A reconnect may have missed events; sync once on connect.
      onChanged();
      _subscription = response.data!.stream.listen(
        (bytes) {
          final chunk = String.fromCharCodes(bytes);
          if (eventsIn(chunk).contains('changed')) onChanged();
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
