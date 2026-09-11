/// Teaching the HTTP client about a trusted certificate is a `dart:io`
/// matter; in a browser the page has no say in what is trusted.
library;

export 'certificate_trust_adapter_web.dart'
    if (dart.library.io) 'certificate_trust_adapter_io.dart';
