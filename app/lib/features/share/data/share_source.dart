import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/share/data/shared_content.dart';

/// Where shares from other apps come from.
abstract interface class ShareSource {
  /// The share that started the app, handed over once; null when the app
  /// was started any other way.
  Future<SharedContent?> initial();

  /// Shares arriving while the app runs.
  Stream<SharedContent> get incoming;
}

/// Everywhere but Android: nothing can be shared into nemo.
class NoShareSource implements ShareSource {
  const NoShareSource();

  @override
  Future<SharedContent?> initial() async => null;

  @override
  Stream<SharedContent> get incoming => const Stream.empty();
}

/// Android's share sheet, through `ShareIntake.kt` in the app's activity.
class ChannelShareSource implements ShareSource {
  ChannelShareSource([this._channel = const MethodChannel(name)]) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'shared') return;
      final content = decode(call.arguments);
      if (content != null) _incoming.add(content);
    });
  }

  static const name = 'dev.ben.nemo/share';

  final MethodChannel _channel;
  final _incoming = StreamController<SharedContent>.broadcast();

  @override
  Future<SharedContent?> initial() async {
    try {
      return decode(await _channel.invokeMethod<Object?>('initial'));
    } on MissingPluginException {
      // An engine without the activity's plugin: a test, or a background
      // isolate. Nothing was shared with it.
      return null;
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_incoming.close());
  }

  @override
  Stream<SharedContent> get incoming => _incoming.stream;

  /// The channel's `{text, subject, images}` map, or null for anything
  /// else -- including a share with nothing in it.
  @visibleForTesting
  static SharedContent? decode(Object? payload) {
    if (payload is! Map) return null;
    final text = payload['text'];
    final subject = payload['subject'];
    final images = payload['images'];
    final content = SharedContent(
      text: text is String ? text : null,
      subject: subject is String ? subject : null,
      images: images is List
          ? images.whereType<Uint8List>().toList()
          : const [],
    );
    final empty =
        (content.text?.trim() ?? '').isEmpty &&
        (content.subject?.trim() ?? '').isEmpty &&
        content.images.isEmpty;
    return empty ? null : content;
  }
}

/// The share sheet's source for this platform; tests hand in a fake.
final shareSourceProvider = Provider<ShareSource>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoShareSource();
  }
  final source = ChannelShareSource();
  ref.onDispose(source.dispose);
  return source;
});
