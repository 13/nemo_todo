/// Server settings, read from the environment in production.
class Config {
  const Config({
    this.port = 8080,
    this.dbPath = '/data/nemo.db',
    this.allowSignup,
    this.webDir = '/app/web',
    this.corsOrigins = const [],
    this.nodeId = 'server',
  });

  factory Config.fromEnv(Map<String, String> env) {
    String? read(String key) {
      final value = env[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final port = read('NEMO_PORT');
    final origins = read('NEMO_CORS_ORIGINS');
    return Config(
      port: port == null ? 8080 : int.parse(port),
      dbPath: read('NEMO_DB') ?? '/data/nemo.db',
      allowSignup: switch (read('NEMO_ALLOW_SIGNUP')?.toLowerCase()) {
        'true' || '1' || 'yes' => true,
        'false' || '0' || 'no' => false,
        _ => null,
      },
      webDir: read('NEMO_WEB_DIR') ?? '/app/web',
      corsOrigins: origins == null
          ? const []
          : origins
                .split(',')
                .map((o) => o.trim())
                .where((o) => o.isNotEmpty)
                .toList(),
      nodeId: read('NEMO_NODE_ID') ?? 'server',
    );
  }

  final int port;
  final String dbPath;

  /// `null` means "open until the first account exists".
  final bool? allowSignup;
  final String webDir;
  final List<String> corsOrigins;
  final String nodeId;
}
