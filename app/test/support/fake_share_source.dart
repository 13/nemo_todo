import 'dart:async';

import 'package:nemo/features/share/data/share_source.dart';
import 'package:nemo/features/share/data/shared_content.dart';

/// Shares a test hands in, as Android's share sheet would: [launch] as the
/// one that started the app, [send] for one arriving while it runs.
class FakeShareSource implements ShareSource {
  FakeShareSource({this.launch});

  SharedContent? launch;
  final _incoming = StreamController<SharedContent>.broadcast();

  void send(SharedContent content) => _incoming.add(content);

  Future<void> close() => _incoming.close();

  @override
  Future<SharedContent?> initial() async {
    final first = launch;
    launch = null;
    return first;
  }

  @override
  Stream<SharedContent> get incoming => _incoming.stream;
}
