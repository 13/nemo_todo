import 'package:dio/dio.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';

/// Nothing to do in a browser: it decides what it trusts before the page
/// is allowed to ask, and the user teaches it in its own settings.
void applyCertificateTrust(Dio dio, CertificateTrust trust) {}
