import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Which build this is, beyond its version: when it was made, from which
/// commit, and by whom -- the release workflow, CI on main, or someone's
/// own machine.
///
/// Stamped in with `--dart-define` by the workflows and the Dockerfile.
/// Nothing reads the clock or git at run time, so a build made from a
/// working copy says so plainly rather than claiming a date it cannot know.
@immutable
class BuildInfo {
  const BuildInfo({this.commit = '', this.builtAt, this.channel = 'dev'});

  /// What the build tools passed in, read once at compile time.
  factory BuildInfo.fromEnvironment() => BuildInfo.parse(
    commit: const String.fromEnvironment('NEMO_COMMIT'),
    builtAt: const String.fromEnvironment('NEMO_BUILD_DATE'),
    channel: const String.fromEnvironment('NEMO_CHANNEL'),
  );

  /// Reads raw values leniently: a date that will not parse is no date,
  /// and a missing channel is a local build.
  factory BuildInfo.parse({
    required String commit,
    required String builtAt,
    required String channel,
  }) => BuildInfo(
    commit: commit.trim(),
    builtAt: DateTime.tryParse(builtAt.trim())?.toUtc(),
    channel: channel.trim().isEmpty ? 'dev' : channel.trim(),
  );

  /// The full commit hash, or empty when nobody said.
  final String commit;
  final DateTime? builtAt;

  /// `release`, `main` or `dev`.
  final String channel;

  /// The seven characters people actually quote, or null.
  String? get shortCommit => shortenCommit(commit);
}

/// The first seven characters of [commit], or null when there is none.
String? shortenCommit(String? commit) {
  final value = commit?.trim() ?? '';
  if (value.isEmpty) return null;
  return value.length <= 7 ? value : value.substring(0, 7);
}

final buildInfoProvider = Provider<BuildInfo>(
  (_) => BuildInfo.fromEnvironment(),
);
