import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:nemo/core/db/kv_store.dart';

/// A certificate a server offered, described well enough for someone to
/// decide whether it is theirs.
class ServerCertificate {
  const ServerCertificate({
    required this.host,
    required this.subject,
    required this.issuer,
    required this.expires,
    required this.fingerprint,
  });

  final String host;
  final String subject;
  final String issuer;
  final DateTime expires;

  /// SHA-256 of the certificate itself, as uppercase hex pairs.
  final String fingerprint;
}

/// Certificates the user has looked at and decided to trust, one per host.
///
/// A nemo server on a home network usually carries a certificate from a
/// private authority rather than a public one. A browser can be taught
/// about that authority, and so can Android -- but not in a way the app
/// would see: Dart's HTTP client reads the system store and nothing else,
/// so a certificate authority installed by hand is invisible to it and
/// every request fails the handshake.
///
/// So the app asks instead. It shows the fingerprint of the certificate it
/// was offered, the name that issued it and how long it is good for, and
/// remembers the answer for that host. Trust is pinned to the exact
/// certificate: a different one on the same host is refused again, and
/// asked about again.
class CertificateTrust {
  CertificateTrust(this._kv, {Map<String, String> trusted = const {}})
    : _trusted = {...trusted};

  final KvStore _kv;

  /// Host to the fingerprint approved for it.
  final Map<String, String> _trusted;

  /// The last certificate refused per host, waiting to be asked about.
  final Map<String, ServerCertificate> _refused = {};

  /// Reads back what [trust] stored. Anything unreadable is treated as
  /// nothing trusted, which fails closed.
  static Map<String, String> decode(String? stored) {
    if (stored == null || stored.isEmpty) return const {};
    try {
      final json = jsonDecode(stored);
      if (json is! Map) return const {};
      return {
        for (final entry in json.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return const {};
    }
  }

  /// The fingerprint of [der], formatted the way servers print theirs.
  static String fingerprintOf(List<int> der) => sha256
      .convert(der)
      .bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');

  bool allows(String host, String fingerprint) => _trusted[host] == fingerprint;

  String? fingerprintFor(String host) => _trusted[host];

  /// Records a certificate the app has just refused, so the screen that
  /// asked for the connection can offer it to the user.
  void refused(ServerCertificate certificate) =>
      _refused[certificate.host] = certificate;

  ServerCertificate? refusedFor(String host) => _refused[host];

  Future<void> trust(ServerCertificate certificate) async {
    _trusted[certificate.host] = certificate.fingerprint;
    _refused.remove(certificate.host);
    await _save();
  }

  Future<void> forget(String host) async {
    if (_trusted.remove(host) == null) return;
    await _save();
  }

  Future<void> _save() =>
      _kv.set(KvKeys.trustedCertificates, jsonEncode(_trusted));
}
