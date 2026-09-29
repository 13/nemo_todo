import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/app.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/settings/data/server_build.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/nemo_server.dart' as server;
import 'package:shelf/shelf.dart' show Handler;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'support/fake_celebrations.dart';
import 'support/test_db.dart';

/// Two installations of the whole app, side by side, syncing through one
/// real server.
///
/// `against_real_server_test.dart` holds the app's sync engine to the real
/// server's protocol; the server's own `e2e_sync_test.dart` plays several
/// devices, but devices it wrote itself. Here nothing between a tap on one
/// phone and a row on the other is a stand-in: both are `NemoApp` as
/// `main` starts it, each with its own database, signed in through the
/// Account screen, editing through the screens people use, and syncing
/// over HTTP to the server's actual handler on a port and a database file.
/// Syncs happen the way they do on a device -- a couple of seconds after
/// an edit, and on a pull -- rather than by calling the engine.
///
/// The widget test clock is fake while the server's sockets are real, so
/// [_Rig.until] lets the real event loop turn between frames.
void main() {
  late _Server srv;
  // Two phones are two AppDatabases on purpose, each over its own
  // in-memory file; drift's warning about sharing one executor is moot.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    // flutter_test answers every HttpClient request with a 400 unless told
    // otherwise, so a test cannot reach the network by accident. This one
    // means to reach the server below.
    HttpOverrides.global = null;
    srv = _Server();
    await srv.start();
  });

  tearDown(() => srv.stop());

  testWidgets('a task added on one phone is ticked off on the other', (
    tester,
  ) async {
    final rig = await _Rig.pump(tester, srv);
    final (anna, ben) = (rig.left, rig.right);

    await rig.connect(anna, signUp: true);
    await rig.quickAdd(anna, 'Buy milk');
    await rig.untilSynced(anna, 'the new task reached the server');
    expect(anna.state.pending, 0);

    await rig.connect(ben);
    expect(ben.on(find.text('Buy milk')), findsOneWidget);
    // Each phone made an Inbox before it had an account; the second to
    // sign in merges into the first rather than showing two.
    expect(await ben.liveInboxes(), ['anna-l1']);

    await rig.tickOff(ben, 'Buy milk');
    expect(ben.on(find.text('1 completed')), findsOneWidget);
    await rig.untilSynced(ben, 'the tick reached the server');

    expect(anna.on(find.text('1 completed')), findsNothing);
    await rig.pull(anna, find.text('Buy milk'));
    expect(anna.on(find.text('1 completed')), findsOneWidget);
    expect(anna.on(find.text('Buy milk')), findsNothing);
    expect((await anna.task('Buy milk')).done, isTrue);

    await rig.finish();
  });

  group('both phones rename one task offline', () {
    /// Both signed in with one task between them; then the server goes
    /// away and each renames the task, anna first. Each tries to sync,
    /// finds nobody there, and keeps its edit queued.
    Future<_Rig> renamedOffline(WidgetTester tester) async {
      final rig = await _Rig.pump(tester, srv);
      final (anna, ben) = (rig.left, rig.right);
      await rig.connect(anna, signUp: true);
      await rig.quickAdd(anna, 'Buy milk');
      await rig.untilSynced(anna, 'the new task reached the server');
      await rig.connect(ben);

      await tester.runAsync(srv.down);
      await rig.rename(anna, 'Buy milk', 'Buy oat milk');
      // The stamps are the real wall clock; a few milliseconds between the
      // two edits makes ben's the later one, which is what decides.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await rig.rename(ben, 'Buy milk', 'Buy soy milk');
      await rig.until(
        () =>
            anna.state.status == SyncStatus.offline &&
            ben.state.status == SyncStatus.offline,
        'both phones found the server gone',
      );
      expect((anna.state.pending, ben.state.pending), (1, 1));
      await tester.runAsync(srv.up);
      return rig;
    }

    Future<void> expectBothSay(_Rig rig, String title) async {
      for (final phone in [rig.left, rig.right]) {
        expect(phone.on(find.text(title)), findsOneWidget, reason: phone.name);
        expect(phone.state.pending, 0, reason: phone.name);
      }
      expect(await rig.serverTitles(), [title]);
    }

    testWidgets('the earlier edit syncs first, and the later replaces it', (
      tester,
    ) async {
      final rig = await renamedOffline(tester);
      final (anna, ben) = (rig.left, rig.right);

      await rig.pull(anna, find.text('Buy oat milk'));
      expect(await rig.serverTitles(), ['Buy oat milk']);
      await rig.pull(ben, find.text('Buy soy milk'));
      expect(await rig.serverTitles(), ['Buy soy milk']);
      // Anna hears of ben's edit on her next sync.
      expect(anna.on(find.text('Buy oat milk')), findsOneWidget);
      await rig.pull(anna, find.text('Buy oat milk'));

      await expectBothSay(rig, 'Buy soy milk');
      await rig.finish();
    });

    testWidgets('the later edit syncs first, and the earlier loses to it', (
      tester,
    ) async {
      final rig = await renamedOffline(tester);
      final (anna, ben) = (rig.left, rig.right);

      await rig.pull(ben, find.text('Buy soy milk'));
      // Anna's edit reaches a server that already holds something newer:
      // it is dropped there, and she is given ben's instead.
      await rig.pull(anna, find.text('Buy oat milk'));
      expect(anna.on(find.text('Buy soy milk')), findsOneWidget);
      await rig.pull(ben, find.text('Buy soy milk'));

      await expectBothSay(rig, 'Buy soy milk');
      await rig.finish();
    });
  });
}

/// The nemo server on a loopback port and a database file of its own, as
/// `nemo_server serve` runs it, minus the web app.
class _Server {
  late final Directory _dir;
  late final server.ServerDatabase _db;
  late final Handler _handler;
  HttpServer? _http;
  int _port = 0;

  String get url => 'http://${InternetAddress.loopbackIPv4.address}:$_port';

  Future<void> start() async {
    _dir = Directory.systemTemp.createTempSync('nemo-two-devices');
    _db = server.ServerDatabase.file('${_dir.path}/nemo.db');
    _handler = server.createHandler(
      db: _db,
      config: server.Config(
        allowSignup: true,
        webDir: '/nonexistent',
        blobDir: '${_dir.path}/blobs',
      ),
    );
    await up();
  }

  /// Listens again, on the same port, so a phone's stored address still
  /// finds it.
  Future<void> up() async {
    _http = await shelf_io.serve(_handler, InternetAddress.loopbackIPv4, _port);
    _port = _http!.port;
  }

  /// Stops listening: what a phone sees of a server that is down, or of
  /// being offline itself -- the connection is refused.
  Future<void> down() async {
    await _http?.close(force: true);
    _http = null;
  }

  /// Every live task's title, as the server holds them.
  Future<List<String>> titles() async => [
    for (final task in await _db.select(_db.tasks).get())
      if (task.deletedAt == null) task.title,
  ];

  Future<void> stop() async {
    await down();
    await _db.close();
    _dir.deleteSync(recursive: true);
  }
}

/// One installation of the app: its own database, session and node.
class _Phone {
  _Phone(this.name, this.db, this.container);

  final String name;
  final AppDatabase db;
  final ProviderContainer container;

  /// Syncs this phone has finished, successfully or not.
  int syncs = 0;

  SyncState get state => container.read(syncEngineProvider);

  /// [finder], on this phone's screen only.
  Finder on(Finder finder) =>
      find.descendant(of: find.byKey(ValueKey(name)), matching: finder);

  Future<Task> task(String title) async => (await (db.select(
    db.tasks,
  )..where((t) => t.title.equals(title))).get()).single;

  Future<List<String>> liveInboxes() async => [
    for (final list in await db.select(db.lists).get())
      if (list.isInbox && list.deletedAt == null) list.id,
  ];
}

/// Two phones on one screen, each half of it.
class _Rig {
  _Rig._(this.tester, this.server, this.left, this.right);

  final WidgetTester tester;
  final _Server server;
  final _Phone left;
  final _Phone right;

  static const _phone = Size(400, 800);

  static Future<_Rig> pump(WidgetTester tester, _Server server) async {
    tester.view.physicalSize = Size(_phone.width * 2, _phone.height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final left = await _install(tester, 'anna');
    final right = await _install(tester, 'ben');
    Widget half(_Phone phone) => SizedBox.fromSize(
      size: _phone,
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(size: _phone),
        child: UncontrolledProviderScope(
          key: ValueKey(phone.name),
          container: phone.container,
          child: const NemoApp(),
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [half(left), half(right)]),
      ),
    );
    await tester.pumpAndSettle();
    return _Rig._(tester, server, left, right);
  }

  /// A fresh install, set up the way `main` sets one up.
  static Future<_Phone> _install(WidgetTester tester, String name) async {
    final db = testDatabase();
    addTearDown(db.close);
    // Each phone names its rows its own way, as random ids would: an Inbox
    // called l1 on both would merge by accident rather than by design.
    await ListsRepository(
      db,
      testClock(name),
      sequentialIds('$name-l'),
    ).ensureInbox();
    // Confetti over the list would hide the rows the test looks for.
    await KvStore(db).set(KvKeys.celebrations, 'false');
    await KvStore(db).set(KvKeys.achievements, 'false');
    final boot = await AppBootstrap.load(db);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        // Which day it is, for Today; sync stamps use the real clock.
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds('$name-')),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        serverBuildFetcherProvider.overrideWithValue((_) async => null),
        celebrationSoundProvider.overrideWithValue(RecordingCelebrationSound()),
        updatesSupportedProvider.overrideWithValue(false),
        authRequiredProvider.overrideWithValue(false),
        authStorageProvider.overrideWithValue(MemoryAuthStorage()),
        // The live event stream is a request that never ends, which a
        // test cannot wait out; syncs are asked for by edits and pulls.
        sseClientFactoryProvider.overrideWithValue((_, _, _) => null),
        // A failed sync tries again by itself after a few seconds, which
        // would decide for the test which phone reaches a server that has
        // just come back first. Here only edits and pulls sync.
        syncRetryPolicyProvider.overrideWithValue((
          initial: const Duration(hours: 1),
          max: const Duration(hours: 1),
        )),
      ],
    );
    final phone = _Phone(name, db, container);
    container.listen(syncEngineProvider.select((s) => s.status), (
      previous,
      next,
    ) {
      if (previous == SyncStatus.syncing && next != SyncStatus.syncing) {
        phone.syncs++;
      }
    });
    return phone;
  }

  Future<List<String>?> serverTitles() => tester.runAsync(server.titles);

  /// Frames and the real event loop in turn, until [done].
  ///
  /// Frames advance the fake clock, which runs the app's debounces and
  /// retries; the pause in between lets the server's socket answer.
  Future<void> until(bool Function() done, String what) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('timed out waiting until $what');
  }

  /// Waits for [phone]'s next sync to finish, and for it to have worked.
  Future<void> untilSynced(_Phone phone, String what) async {
    final before = phone.syncs;
    await until(() => phone.syncs > before, what);
    expect(phone.state.status, SyncStatus.idle, reason: what);
  }

  /// Signs [phone] in through the Account screen, from Today's app bar.
  Future<void> connect(_Phone phone, {bool signUp = false}) async {
    await tester.tap(phone.on(find.byKey(const Key('account-action'))));
    await tester.pumpAndSettle();
    await tester.enterText(
      phone.on(find.byKey(const Key('account-server'))),
      server.url,
    );
    await tester.enterText(
      phone.on(find.byKey(const Key('account-username'))),
      'household',
    );
    await tester.enterText(
      phone.on(find.byKey(const Key('account-password'))),
      'password123',
    );
    await tester.tap(
      phone.on(find.byKey(Key(signUp ? 'account-sign-up' : 'account-sign-in'))),
    );
    // The screen closes itself once the first sync is done. That can leave
    // one more change behind -- a second Inbox, merged into the account's
    // own when it arrived -- which the next sync, moments later, sends.
    await until(
      () =>
          phone
              .on(find.byKey(const Key('account-server')))
              .evaluate()
              .isEmpty &&
          phone.state.status == SyncStatus.idle &&
          phone.state.pending == 0,
      '${phone.name} signed in and synced',
    );
    await tester.pumpAndSettle();
  }

  Future<void> quickAdd(_Phone phone, String title) async {
    await tester.enterText(
      phone.on(find.byKey(const Key('quick-add-field'))),
      title,
    );
    await tester.tap(phone.on(find.byKey(const Key('quick-add-submit'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(phone.on(find.text(title)), findsOneWidget);
  }

  Future<void> tickOff(_Phone phone, String title) async {
    await tester.tap(
      phone.on(
        find.descendant(
          of: find.widgetWithText(InkWell, title),
          matching: find.byType(DoneCheck),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Opens the task, retypes its title, and goes back to Today.
  Future<void> rename(_Phone phone, String from, String to) async {
    await tester.tap(phone.on(find.text(from)));
    await tester.pumpAndSettle();
    await tester.enterText(phone.on(find.byKey(const Key('task-title'))), to);
    // Past the editor's own debounce, so the edit is saved and stamped now.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(phone.on(find.text(to)), findsOneWidget);
  }

  /// Pulls [phone]'s list down by [row], and waits for the sync that
  /// starts to finish.
  Future<void> pull(_Phone phone, Finder row) async {
    final before = phone.syncs;
    await tester.fling(phone.on(row), const Offset(0, 400), 1000);
    await until(() => phone.syncs > before, '${phone.name} pulled');
    await tester.pumpAndSettle();
    expect(phone.state.status, SyncStatus.idle);
  }

  /// Takes both phones down inside the test, as `appTest` does, so the
  /// timers drift schedules on close run while the framework is watching.
  Future<void> finish() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Each phone's HTTP client keeps its connection open for the next
    // request, on a timer of the test's fake clock.
    for (final phone in [left, right]) {
      phone.container.read(dioProvider).close(force: true);
    }
    left.container.dispose();
    right.container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
  }
}
