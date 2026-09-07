import 'dart:io';

/// Fails the build when line coverage drops below a floor.
///
/// Generated sources are excluded: freezed and riverpod output, and the
/// localisation catalogues, whose coverage measures how many strings a test
/// happened to render rather than anything about the code.
///
/// Everything else under lib/ counts, including files lcov never mentions.
/// It only lists files some test imported, so a screen with no test at all
/// was not scored zero -- it was absent, and the percentage was quietly
/// computed over the rest. That let whole screens sit outside the floor:
/// the router's redirect, the scheduled screen, the audit screen. A file
/// nothing loads is the least covered code there is, so it is counted at
/// zero and named in the list below.
///
/// Usage: dart run tool/check_coverage.dart [minimum-percent]
const _generated = [
  '.g.dart',
  '.freezed.dart',
  'lib/l10n/app_localizations',
];

void main(List<String> args) {
  final minimum = args.isEmpty ? 60.0 : double.parse(args.first);
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found; run flutter test --coverage');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  final worst = <({double ratio, int hit, int found, String path})>[];
  String? path;
  var fileFound = 0;
  var fileHit = 0;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      path = line.substring(3);
      fileFound = 0;
      fileHit = 0;
    } else if (line.startsWith('LF:')) {
      fileFound = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      fileHit = int.parse(line.substring(3));
    } else if (line == 'end_of_record' && path != null) {
      final current = path;
      final isGenerated = _generated.any(current.contains);
      if (!isGenerated && fileFound > 0) {
        found += fileFound;
        hit += fileHit;
        worst.add((
          ratio: fileHit / fileFound,
          hit: fileHit,
          found: fileFound,
          path: current,
        ));
      }
      path = null;
    }
  }

  // Files lcov never mentioned, counted at zero rather than skipped.
  final measured = worst.map((e) => e.path).toSet();
  for (final source in _firstPartySources()) {
    if (measured.contains(source.path)) continue;
    final lines = source.readAsLinesSync().where(_isCountable).length;
    if (lines == 0) continue;
    found += lines;
    worst.add((ratio: 0, hit: 0, found: lines, path: source.path));
  }

  if (found == 0) {
    stderr.writeln('no coverage data for first-party code');
    exit(1);
  }

  final percent = hit / found * 100;
  stdout.writeln(
    'line coverage (excluding generated): '
    '$hit/$found = ${percent.toStringAsFixed(1)}%',
  );

  worst.sort((a, b) => a.ratio.compareTo(b.ratio));
  stdout.writeln('\nleast covered:');
  for (final entry in worst.take(10)) {
    final pct = (entry.ratio * 100).toStringAsFixed(1).padLeft(5);
    stdout.writeln('  $pct%  ${entry.hit}/${entry.found}  ${entry.path}');
  }

  if (percent < minimum) {
    stderr.writeln(
      '\ncoverage ${percent.toStringAsFixed(1)}% is below the '
      '${minimum.toStringAsFixed(0)}% floor',
    );
    exit(1);
  }
}

/// Every first-party Dart file under lib/, generated output aside.
Iterable<File> _firstPartySources() sync* {
  final dir = Directory('lib');
  if (!dir.existsSync()) return;
  for (final entry in dir.listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.dart')) continue;
    if (_generated.any(entry.path.contains)) continue;
    yield entry;
  }
}

/// Roughly what lcov would call an executable line, so an unimported file is
/// weighed on the same scale as an imported one rather than by its imports
/// and comments. Approximate on purpose: it decides how loudly an untested
/// file counts against the floor, not whether it counts at all.
bool _isCountable(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  if (trimmed.startsWith('//')) return false;
  if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
    return false;
  }
  if (trimmed.startsWith('part ')) return false;
  return true;
}
