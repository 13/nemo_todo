/// An error the HTTP layer turns into `{"error": code}` with [status].
class ApiException implements Exception {
  const ApiException(this.status, this.code);

  final int status;
  final String code;

  @override
  String toString() => 'ApiException($status, $code)';
}
