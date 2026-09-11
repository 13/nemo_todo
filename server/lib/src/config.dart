/// Server settings, read from the environment in production.
class Config {
  const Config({
    this.port = 8080,
    this.dbPath = '/data/nemo.db',
    this.allowSignup,
    this.webDir = '/app/web',
    this.corsOrigins = const [],
    this.nodeId = 'server',
    this.trustedProxyHops = 0,
    this.version = 'dev',
  });

  factory Config.fromEnv(Map<String, String> env) {
    String? read(String key) {
      final value = env[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final port = read('NEMO_PORT');
    final hops = read('NEMO_TRUSTED_PROXY_HOPS');
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
      trustedProxyHops: hops == null ? 0 : int.parse(hops),
      version: read('NEMO_VERSION') ?? 'dev',
    );
  }

  final int port;
  final String dbPath;

  /// `null` means "open until the first account exists".
  final bool? allowSignup;
  final String webDir;
  final List<String> corsOrigins;
  final String nodeId;

  /// What this build calls itself, baked into the image at build time and
  /// reported to anyone who asks. `dev` when nobody said, which is what a
  /// build from a working copy is.
  final String version;

  /// How many proxies of our own sit in front of the server. Zero means the
  /// server is reached directly, so `x-forwarded-for` is whatever the client
  /// chose to send and is ignored. Set it to the number of proxies that
  /// rewrite the header, or per-client limits count a header, not a client.
  final int trustedProxyHops;
}
