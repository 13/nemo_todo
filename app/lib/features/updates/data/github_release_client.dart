import 'package:dio/dio.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

enum UpdateFailure { network, rateLimited, notFound, malformed }

class UpdateException implements Exception {
  const UpdateException(this.failure);

  final UpdateFailure failure;

  @override
  String toString() => 'UpdateException(${failure.name})';
}

/// Reads the newest published release. Drafts and pre-releases never
/// appear at this endpoint, so nothing has to filter them out.
class GithubReleaseClient {
  GithubReleaseClient(this._dio, {this.repository = '13/nemo_todo'});

  final Dio _dio;
  final String repository;

  Future<AppRelease> latest() async {
    final Map<String, dynamic> body;
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      body =
          response.data ??
          (throw const UpdateException(UpdateFailure.malformed));
    } on DioException catch (e) {
      throw UpdateException(switch (e.response?.statusCode) {
        403 || 429 => UpdateFailure.rateLimited,
        404 => UpdateFailure.notFound,
        _ => UpdateFailure.network,
      });
    }

    final tag = body['tag_name'] as String? ?? '';
    final version = AppVersion.tryParse(tag);
    if (version == null) throw const UpdateException(UpdateFailure.malformed);

    return AppRelease(
      version: version,
      tag: tag,
      notes: (body['body'] as String? ?? '').trim(),
      assets: [
        for (final asset in body['assets'] as List<dynamic>? ?? const [])
          if (asset is Map<String, dynamic>)
            ReleaseAsset(
              name: asset['name'] as String? ?? '',
              url: asset['browser_download_url'] as String? ?? '',
              size: asset['size'] as int? ?? 0,
              // The API returns "sha256:<hex>"; keep the hex.
              sha256: (asset['digest'] as String?)?.split(':').last,
            ),
      ],
    );
  }
}
