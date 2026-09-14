import 'package:drift/drift.dart' hide isNull;
import 'package:http/http.dart' as http;
import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

import 'support/rows.dart';
import 'support/test_server.dart';

void main() {
  late TestServer server;
  final clock = deviceClock('d');

  tearDown(() => server.close());

  group('changing a password', () {
    test('needs the current one, and keeps only the asking session', () async {
      server = await TestServer.start();
      final phone = await server.signup('ben');
      final laptop =
          json(
                await server.post('/api/v1/auth/login', {
                  'username': 'ben',
                  'password': 'password123',
                }),
              )['token']
              as String;

      final wrong = await server.post('/api/v1/auth/password', {
        'current': 'not it',
        'password': 'a-new-password',
      }, token: phone);
      expect(wrong.statusCode, 403);
      expect(json(wrong), {'error': 'wrong_password'});

      final weak = await server.post('/api/v1/auth/password', {
        'current': 'password123',
        'password': 'short',
      }, token: phone);
      expect(weak.statusCode, 400);
      expect(json(weak), {'error': 'weak_password'});

      final ok = await server.post('/api/v1/auth/password', {
        'current': 'password123',
        'password': 'a-new-password',
      }, token: phone);
      expect(json(ok), {'ok': true});

      expect(
        (await server.get('/api/v1/auth/me', token: phone)).statusCode,
        200,
      );
      expect(
        (await server.get('/api/v1/auth/me', token: laptop)).statusCode,
        401,
        reason: 'every other session is signed out',
      );
      final old = await server.post('/api/v1/auth/login', {
        'username': 'ben',
        'password': 'password123',
      });
      expect(old.statusCode, 401);
      final fresh = await server.post('/api/v1/auth/login', {
        'username': 'ben',
        'password': 'a-new-password',
      });
      expect(fresh.statusCode, 200);
    });
  });

  group('deleting an account', () {
    Future<http.Response> deleteAccount(String token, String password) =>
        http.delete(
          server.uri('/api/v1/account'),
          headers: server.headers(token),
          body: '{"password":"$password"}',
        );

    Future<void> push(String token, List<SyncChange> changes) async {
      final r = await server.post('/api/v1/sync', {
        'cursor': 0,
        'changes': [for (final c in changes) c.toJson()],
      }, token: token);
      expect(r.statusCode, 200, reason: r.body);
    }

    test('refuses a wrong password and changes nothing', () async {
      server = await TestServer.start();
      final token = await server.signup('ben');
      final r = await deleteAccount(token, 'nope');
      expect(r.statusCode, 403);
      expect(
        (await server.get('/api/v1/auth/me', token: token)).statusCode,
        200,
      );
    });

    test(
      'removes the account, its sessions and the lists only it had',
      () async {
        server = await TestServer.start();
        final token = await server.signup('ben');
        await push(token, [
          SyncChange.list(list('l1', clock)),
          SyncChange.task(task('t1', 'l1', clock)),
          SyncChange.subtask(subtask('s1', 't1', clock)),
        ]);

        final r = await deleteAccount(token, 'password123');
        expect(json(r), {'ok': true});

        expect(
          (await server.get('/api/v1/auth/me', token: token)).statusCode,
          401,
        );
        final db = server.db;
        expect(await db.select(db.users).get(), isEmpty);
        expect(await db.select(db.sessions).get(), isEmpty);
        expect(await db.select(db.lists).get(), isEmpty);
        expect(await db.select(db.tasks).get(), isEmpty);
        expect(await db.select(db.subtasks).get(), isEmpty);
        expect(await db.select(db.listMembers).get(), isEmpty);
        expect(await db.select(db.syncLog).get(), isEmpty);

        // The name is free again.
        await server.signup('ben');
      },
    );

    test(
      'hands a shared list to the next member and leaves theirs alone',
      () async {
        server = await TestServer.start();
        final ben = await server.signup('ben');
        final zoe = await server.signup('zoe');
        await server.signup('amy');
        await push(ben, [
          SyncChange.list(list('shared', clock)),
          SyncChange.task(task('t1', 'shared', clock)),
        ]);
        await push(zoe, [SyncChange.list(list('zoes', clock))]);
        for (final name in ['zoe', 'amy']) {
          final r = await server.post('/api/v1/lists/shared/members', {
            'username': name,
          }, token: ben);
          expect(r.statusCode, 200, reason: r.body);
        }
        final r = await server.post('/api/v1/lists/zoes/members', {
          'username': 'ben',
        }, token: zoe);
        expect(r.statusCode, 200, reason: r.body);

        expect(json(await deleteAccount(ben, 'password123')), {'ok': true});

        final members =
            json(
                  await server.get('/api/v1/lists/shared/members', token: zoe),
                )['members']
                as List<dynamic>;
        expect(members, [
          {'username': 'amy', 'role': 'owner'},
          {'username': 'zoe', 'role': 'editor'},
        ]);
        final db = server.db;
        final shared = (await db.select(db.lists).get()).firstWhere(
          (l) => l.id == 'shared',
        );
        final amyId = (await db.select(db.users).get())
            .firstWhere((u) => u.username == 'amy')
            .id;
        expect(shared.ownerId, amyId);
        expect(await db.select(db.tasks).get(), hasLength(1));

        final zoes =
            json(
                  await server.get('/api/v1/lists/zoes/members', token: zoe),
                )['members']
                as List<dynamic>;
        expect(zoes, [
          {'username': 'zoe', 'role': 'owner'},
        ]);
        // The list travels again, so every remaining member's next sync
        // hears who owns it now.
        final log =
            await (db.select(db.syncLog)..where(
                  (t) => t.rowId.equals('shared') & t.op.equals('upsert'),
                ))
                .get();
        expect(log.single.forUserId, isNull);
      },
    );
  });
}
