import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';
import 'package:nemo/features/auth/data/certificate_trust_adapter.dart';

import '../../support/test_db.dart';

/// A fingerprint as the app prints one: 32 uppercase hex pairs.
final fingerprintFormat = RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$');

/// A server holding a certificate nothing on this machine has heard of,
/// which is what a nemo server behind a private authority looks like to
/// the app.
Future<HttpServer> selfSignedServer() async {
  final context = SecurityContext()
    ..useCertificateChain('test/support/self_signed_cert.pem')
    ..usePrivateKey('test/support/self_signed_key.pem');
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    context,
  );
  server.listen((request) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write('{"ok":true}');
    await request.response.close();
  });
  return server;
}

void main() {
  late KvStore kv;

  setUp(() {
    final db = testDatabase();
    addTearDown(db.close);
    kv = KvStore(db);
  });

  test('a fingerprint is the hex of the certificate, in pairs', () {
    expect(
      CertificateTrust.fingerprintOf([0x00, 0x01, 0xff]),
      matches(fingerprintFormat),
    );
  });

  test('what is trusted survives being written and read back', () async {
    final trust = CertificateTrust(kv);
    await trust.trust(
      ServerCertificate(
        host: 'nemo.example',
        subject: 'CN=nemo.example',
        issuer: 'CN=Example Root',
        expires: DateTime(2036),
        fingerprint: 'AA:BB',
      ),
    );

    final reopened = CertificateTrust(
      kv,
      trusted: CertificateTrust.decode(
        await kv.get(KvKeys.trustedCertificates),
      ),
    );
    expect(reopened.allows('nemo.example', 'AA:BB'), isTrue);
    // Pinned to the certificate, not to the host: a different one on the
    // same host has to be asked about again.
    expect(reopened.allows('nemo.example', 'CC:DD'), isFalse);
    expect(reopened.allows('other.example', 'AA:BB'), isFalse);

    await reopened.forget('nemo.example');
    expect(
      CertificateTrust.decode(await kv.get(KvKeys.trustedCertificates)),
      isEmpty,
    );
  });

  test('stored nonsense trusts nothing rather than throwing', () {
    expect(CertificateTrust.decode(null), isEmpty);
    expect(CertificateTrust.decode('not json'), isEmpty);
    expect(CertificateTrust.decode('[1,2]'), isEmpty);
    expect(CertificateTrust.decode('{"host":42}'), isEmpty);
  });

  test(
    'a certificate the system cannot verify is refused, then trusted',
    () async {
      final server = await selfSignedServer();
      addTearDown(() => server.close(force: true));
      final url = 'https://127.0.0.1:${server.port}/api/v1/healthz';

      final trust = CertificateTrust(kv);
      final dio = Dio();
      applyCertificateTrust(dio, trust);

      // As it stands: the handshake fails, and all the app can say is that
      // it could not reach the server.
      await expectLater(dio.get<void>(url), throwsA(isA<DioException>()));

      // The certificate it was offered is kept, so it can be shown.
      final offered = trust.refusedFor('127.0.0.1');
      expect(offered, isNotNull);
      expect(offered!.host, '127.0.0.1');
      expect(offered.issuer, contains('nemo.test'));
      expect(offered.fingerprint, matches(fingerprintFormat));

      // Once the user has agreed to it, the same server answers.
      await trust.trust(offered);
      final response = await dio.get<Map<String, dynamic>>(url);
      expect(response.data, {'ok': true});

      // And that agreement covers that certificate on that host, no more.
      expect(trust.allows('127.0.0.1', offered.fingerprint), isTrue);
      expect(trust.allows('nemo.example', offered.fingerprint), isFalse);
    },
  );
}
