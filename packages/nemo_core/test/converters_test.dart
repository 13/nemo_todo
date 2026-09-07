import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  test('StringListConverter round trips through JSON text', () {
    const c = StringListConverter();
    expect(c.toSql(['a', 'b']), '["a","b"]');
    expect(c.fromSql('["a","b"]'), ['a', 'b']);
    expect(c.fromSql('[]'), isEmpty);
  });
}
