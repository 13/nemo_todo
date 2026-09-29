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
    ..addCommand(_BackupCommand())
    ..addCommand(_PurgeCommand())
    ..addCommand(_StatusCommand())
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

    // An expired session is otherwise only noticed when its own token comes
    // back, which for an abandoned one never happens.
    final auth = AuthService(db);
    Future<void> sweep() async {
      final removed = await auth.deleteExpiredSessions();
      if (removed > 0) log.info('swept $removed expired session(s)');
    }

    await sweep();
    final sweeper = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(sweep()),
    );
    final server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      config.port,
    );
    final stopped = Completer<void>();
    var stopping = false;
    Future<void> stop(ProcessSignal signal) async {
      if (stopping) return;
      stopping = true;
      log.info('received $signal, shutting down');
      sweeper.cancel();
      await server.close(force: true);
      await hub.close();
      await db.close();
      stopped.complete();
    }

    // Watched before the server says it is listening, so a signal sent as
    // soon as it does is handled rather than killing it mid-start.
    final signals = [
      ProcessSignal.sigterm.watch().listen(stop),
      ProcessSignal.sigint.watch().listen(stop),
    ];
    log.info(
      'nemo server listening on port ${server.port}, '
      'database ${config.dbPath}, web app ${config.webDir}',
    );
    await stopped.future;
    // A signal subscription keeps the process alive on its own: without
    // cancelling them, everything above closes and the process still never
    // exits, so `docker stop` waited out its ten seconds and killed it.
    for (final subscription in signals) {
      await subscription.cancel();
    }
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

class _BackupCommand extends Command<int> {
  @override
  String get name => 'backup';

  @override
  String get description =>
      'Write a consistent copy of the database to <file>, while serving. '
      'Refuses to overwrite an existing file.';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const [];
    if (rest.length != 1) usageException('usage: backup <file>');
    final target = rest.single;
    final config = Config.fromEnv(Platform.environment);
    if (!File(config.dbPath).existsSync()) {
      stderr.writeln('no database at ${config.dbPath}');
      return 1;
    }
    final db = _openDatabase(config);
    try {
      await db.backupTo(target);
      stdout.writeln(
        'wrote $target (${File(target).lengthSync()} bytes) '
        'from ${config.dbPath}',
      );
      return 0;
    } on Object catch (e) {
      stderr.writeln('backup failed: $e');
      return 1;
    } finally {
      await db.close();
    }
  }
}

class _PurgeCommand extends Command<int> {
  _PurgeCommand() {
    argParser
      ..addOption(
        'days',
        help:
            'Delete rows tombstoned longer ago than this many days; '
            '${PurgeService.minimumRetention.inDays} at least, since the app '
            'offers deleted tasks back for that long.',
        defaultsTo: '${PurgeService.defaultRetention.inDays}',
      )
      ..addFlag(
        'dry-run',
        help: 'Report what would go and change nothing.',
        negatable: false,
      );
  }

  @override
  String get name => 'purge';

  @override
  String get description =>
      'Delete old tombstoned rows and their children. Devices are still '
      'told to drop them, so one that has been offline throughout catches '
      'up rather than resurrecting them.';

  @override
  Future<int> run() async {
    final days = int.tryParse(argResults?['days'] as String? ?? '');
    final minimum = PurgeService.minimumRetention.inDays;
    if (days == null || days < minimum) {
      // The app offers a deleted task back for this long.
      usageException('--days must be $minimum or more');
    }
    final dryRun = argResults?['dry-run'] as bool? ?? false;
    final config = Config.fromEnv(Platform.environment);
    if (!File(config.dbPath).existsSync()) {
      stderr.writeln('no database at ${config.dbPath}');
      return 1;
    }
    final db = _openDatabase(config);
    try {
      final report = await PurgeService(db, blobs: BlobStore(config.blobDir))
          .purge(
            retention: Duration(days: days),
            dryRun: dryRun,
          );
      stdout.writeln(
        report.total == 0
            ? 'nothing tombstoned longer than $days day(s)'
            : '${dryRun ? "would remove" : "removed"} $report',
      );
      return 0;
    } finally {
      await db.close();
    }
  }
}

class _StatusCommand extends Command<int> {
  @override
  String get name => 'status';

  @override
  String get description =>
      'Show how big the database is, what it holds, and when housekeeping '
      'last ran. For whoever hosts the server; nothing like it is served '
      'over HTTP.';

  @override
  Future<int> run() async {
    final config = Config.fromEnv(Platform.environment);
    if (!File(config.dbPath).existsSync()) {
      stderr.writeln('no database at ${config.dbPath}');
      return 1;
    }
    final db = _openDatabase(config);
    try {
      final status = await ServerStatus.read(db, dbPath: config.dbPath);
      stdout.writeln(
        status.describe(dbPath: config.dbPath, now: DateTime.now()),
      );
      return 0;
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
