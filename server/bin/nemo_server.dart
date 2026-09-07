import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:nemo_server/nemo_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    final error = r.error == null ? '' : ' ${r.error}';
    stdout.writeln(
      '${r.time.toIso8601String()} ${r.level.name} ${r.message}$error',
    );
    if (r.stackTrace != null) stdout.writeln(r.stackTrace);
  });
  final runner = CommandRunner<int>('nemo_server', 'nemo sync server')
    ..addCommand(_ServeCommand())
    ..addCommand(_ResetPasswordCommand())
    ..addCommand(_HealthcheckCommand());
  try {
    exitCode = await runner.run(args.isEmpty ? const ['serve'] : args) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}

ServerDatabase _openDatabase(Config config) {
  Directory(File(config.dbPath).parent.path).createSync(recursive: true);
  return ServerDatabase.file(config.dbPath);
}

class _ServeCommand extends Command<int> {
  @override
  String get name => 'serve';

  @override
  String get description => 'Run the API and web server (default).';

  @override
  Future<int> run() async {
    final log = Logger('nemo');
    final config = Config.fromEnv(Platform.environment);
    final db = _openDatabase(config);
    final hub = EventHub();
    final handler = createHandler(db: db, config: config, hub: hub);
    final server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      config.port,
    );
    log.info(
      'nemo server listening on port ${server.port}, '
      'database ${config.dbPath}, web app ${config.webDir}',
    );
    final stopped = Completer<void>();
    Future<void> stop(ProcessSignal signal) async {
      if (stopped.isCompleted) return;
      log.info('received $signal, shutting down');
      await server.close(force: true);
      await hub.close();
      await db.close();
      stopped.complete();
    }

    ProcessSignal.sigterm.watch().listen(stop);
    ProcessSignal.sigint.watch().listen(stop);
    await stopped.future;
    return 0;
  }
}

class _ResetPasswordCommand extends Command<int> {
  @override
  String get name => 'reset-password';

  @override
  String get description =>
      'Set a new password for <username> and sign them out everywhere. '
      'Reads NEMO_NEW_PASSWORD or prompts.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.length != 1) usageException('usage: reset-password <username>');
    var password = Platform.environment['NEMO_NEW_PASSWORD'];
    if (password == null || password.isEmpty) {
      stdout.write('New password: ');
      final hadEcho = stdin.hasTerminal && stdin.echoMode;
      if (stdin.hasTerminal) stdin.echoMode = false;
      password = stdin.readLineSync() ?? '';
      if (stdin.hasTerminal) stdin.echoMode = hadEcho;
      stdout.writeln();
    }
    final config = Config.fromEnv(Platform.environment);
    final db = _openDatabase(config);
    try {
      await AuthService(db).resetPassword(rest.single, password);
      stdout.writeln('password updated for ${rest.single}');
      return 0;
    } on ApiException catch (e) {
      stderr.writeln('failed: ${e.code}');
      return 1;
    } finally {
      await db.close();
    }
  }
}

class _HealthcheckCommand extends Command<int> {
  @override
  String get name => 'healthcheck';

  @override
  String get description => 'Exit 0 when the local server answers /healthz.';

  @override
  Future<int> run() async {
    final port = Config.fromEnv(Platform.environment).port;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/healthz'),
      );
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 200 ? 0 : 1;
    } on Object {
      return 1;
    } finally {
      client.close(force: true);
    }
  }
}
