@TestOn('linux || mac-os')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Runs the real `nemo_server serve` in a process of its own, because what
/// is under test is whether that process ends: `docker stop` sends SIGTERM
/// and waits ten seconds before killing a server that shuts down but never
/// exits.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nemo_shutdown_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
    test('the server exits after $signal', () async {
      final server = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'bin/nemo_server.dart', 'serve'],
        environment: {
          'NEMO_PORT': '0',
          'NEMO_DB': '${dir.path}/nemo.db',
          'NEMO_BLOB_DIR': '${dir.path}/blobs',
          'NEMO_WEB_DIR': '${dir.path}/web',
        },
      );
      final listening = Completer<void>();
      final output = StringBuffer();
      void watch(Stream<List<int>> stream) => stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            output.writeln(line);
            if (line.contains('listening') && !listening.isCompleted) {
              listening.complete();
            }
          });
      watch(server.stdout);
      watch(server.stderr);

      await listening.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => fail('never started:\n$output'),
      );
      server.kill(signal);
      final code = await server.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          server.kill(ProcessSignal.sigkill);
          return fail('still running 5 s after $signal:\n$output');
        },
      );
      expect(code, 0, reason: '$output');
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
