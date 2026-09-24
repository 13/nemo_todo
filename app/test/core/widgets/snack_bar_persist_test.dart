import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The argument list of the call whose `(` sits at [open].
String callArgs(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(open, i + 1);
  }
  return source.substring(open);
}

void main() {
  // A SnackBar with an action persists unless told otherwise, so an Undo
  // snackbar would never time out and sit over the screen until tapped.
  test('every SnackBar with an action says whether it persists', () {
    final call = RegExp(r'\bSnackBar\(');
    final missing = <String>[];
    var checked = 0;
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final args = callArgs(source, match.end - 1);
        if (!args.contains('action:')) continue;
        checked++;
        if (!args.contains('persist:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          missing.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(checked, greaterThan(0), reason: 'the scan found no SnackBars');
    expect(missing, isEmpty);
  });
}
