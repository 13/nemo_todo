import 'package:dio/dio.dart';
import 'package:nemo_core/nemo_core.dart';

/// A request the server refused, carrying the code it answered with.
class ApiError implements Exception {
  const ApiError(this.status, this.code);

  /// 0 when the server could not be reached at all.
  final int status;
  final String code;

  bool get isUnauthorized => status == 401;
  bool get isOffline => status == 0;

  @override
  String toString() => 'ApiError($status, $code)';
}

/// Talks to one nemo server on behalf of one signed-in account.
class SyncClient {
  SyncClient(this._dio, {required String baseUrl, required this.token})
    : baseUrl = normaliseBaseUrl(baseUrl);

  final Dio _dio;
  final String baseUrl;
  final String token;

  /// Trims trailing slashes so paths can be appended safely.
  static String normaliseBaseUrl(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// True for an address the app can actually call.
  static bool isValidBaseUrl(String url) {
    final uri = Uri.tryParse(normaliseBaseUrl(url));
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Uri uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Options get _options => Options(
    headers: {'authorization': 'Bearer $token'},
    contentType: 'application/json',
  );

  Future<SyncResponse> sync(SyncRequest request) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.postUri<Map<String, dynamic>>(
        uri('/sync'),
        data: request.toJson(),
        options: _options,
      ),
    );
    return SyncResponse.fromJson(response);
  }

  Future<List<ListMember>> members(String listId) async {
    final response = await _send<Map<String, dynamic>>(
      () => _dio.getUri<Map<String, dynamic>>(
        uri('/lists/$listId/members'),
        options: _options,
      ),
    );
    return [
      for (final m in response['members'] as List<dynamic>)
        ListMember.fromJson(m as Map<String, dynamic>),
    ];
  }

  Future<void> share(String listId, String username, MemberRole role) => _send(
    () => _dio.postUri<Map<String, dynamic>>(
      uri('/lists/$listId/members'),
      data: {'username': username, 'role': role.name},
      options: _options,
    ),
  );

  Future<void> unshare(String listId, String username) => _send(
    () => _dio.deleteUri<Map<String, dynamic>>(
      uri('/lists/$listId/members/$username'),
      options: _options,
    ),
  );

  Future<void> logout() => _send(
    () => _dio.postUri<Map<String, dynamic>>(
      uri('/auth/logout'),
      options: _options,
    ),
  );

  /// Signs in (or signs up) and returns the new session.
  static Future<({String token, String username})> authenticate(
    Dio dio, {
    required String baseUrl,
    required String username,
    required String password,
    required bool signUp,
  }) async {
    final base = normaliseBaseUrl(baseUrl);
    final path = signUp ? 'signup' : 'login';
    final body = await _guard<Map<String, dynamic>>(
      () => dio.postUri<Map<String, dynamic>>(
        Uri.parse('$base/api/v1/auth/$path'),
        data: {'username': username, 'password': password},
        options: Options(contentType: 'application/json'),
      ),
    );
    return (
      token: body['token'] as String,
      username: body['username'] as String,
    );
  }

  Future<T> _send<T>(Future<Response<T>> Function() call) => _guard<T>(call);

  static Future<T> _guard<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data == null) throw const ApiError(0, 'empty_response');
      return data;
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      final code = body is Map<String, dynamic>
          ? body['error'] as String? ?? 'error'
          : status == 0
          ? 'network'
          : 'error';
      throw ApiError(status, code);
    }
  }
}
