import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';

/// Lets [dio] complete a handshake the system store cannot vouch for, but
/// only with the exact certificate the user approved for that host.
///
/// A certificate that is not approved is refused as it would be without
/// this, and noted in [trust] so the screen that asked for the connection
/// can show it and ask.
void applyCertificateTrust(Dio dio, CertificateTrust trust) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () =>
        HttpClient()
          ..badCertificateCallback = (certificate, host, _) {
            final offered = ServerCertificate(
              host: host,
              subject: certificate.subject,
              issuer: certificate.issuer,
              expires: certificate.endValidity,
              fingerprint: CertificateTrust.fingerprintOf(certificate.der),
            );
            if (trust.allows(host, offered.fingerprint)) return true;
            trust.refused(offered);
            return false;
          },
  );
}
