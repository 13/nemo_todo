import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:nemo/core/build_info.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// What the server says about its own build on `/healthz`.
@immutable
class ServerBuild {
  const ServerBuild({required this.version, this.commit, this.builtAt});

  /// Reads the health answer. The commit and date are optional: a server
  /// from before 0.7.0 does not send them, and one built from a working
  /// copy has nothing to send.
  factory ServerBuild.fromJson(Map<String, dynamic> json) => ServerBuild(
    version: json['version'] as String? ?? '',
    commit: json['commit'] as String?,
    builtAt: DateTime.tryParse(json['builtAt'] as String? ?? '')?.toUtc(),
  );

  final String version;
  final String? commit;
  final DateTime? builtAt;

  String? get shortCommit => shortenCommit(commit);
}

/// Asks the server at [baseUrl] how it was built, or null if it will not
/// say. Replaced in tests.
typedef ServerBuildFetcher = Future<ServerBuild?> Function(String baseUrl);

final serverBuildFetcherProvider = Provider<ServerBuildFetcher>((ref) {
  final dio = ref.watch(dioProvider);
  return (baseUrl) async {
    try {
      final base = SyncClient.normaliseBaseUrl(baseUrl);
      final response = await dio.getUri<Map<String, dynamic>>(
        Uri.parse('$base/healthz'),
      );
      final data = response.data;
      return data == null ? null : ServerBuild.fromJson(data);
    } on Object {
      // Only ever shown in About. A server that cannot be reached right
      // now is already said to be offline elsewhere on the same screen.
      return null;
    }
  };
});

/// How the connected server was built. Asked again whenever the sync hears
/// a different version, so an upgraded server is described as it is now.
final serverBuildProvider = FutureProvider<ServerBuild?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  ref.watch(syncEngineProvider.select((s) => s.serverVersion));
  if (!auth.connected) return null;
  return await ref.watch(serverBuildFetcherProvider)(auth.serverUrl!);
});

/// The build number beside the version, e.g. `6` in 0.6.0+6.
final buildNumberProvider = FutureProvider<String>(
  (_) async => (await PackageInfo.fromPlatform()).buildNumber,
);
