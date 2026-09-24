import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/notes/ui/note_tips.dart';

import '../../support/test_db.dart';

void main() {
  test('shouldShow is true until markShown, then false', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final tips = NoteTips(KvStore(db));

    expect(await tips.shouldShow(NoteTips.makeTodo), isTrue);

    await tips.markShown(NoteTips.makeTodo);
    expect(await tips.shouldShow(NoteTips.makeTodo), isFalse);
  });

  test('the two tips are tracked independently', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final tips = NoteTips(KvStore(db));

    await tips.markShown(NoteTips.makeTodo);

    expect(await tips.shouldShow(NoteTips.makeTodo), isFalse);
    expect(await tips.shouldShow(NoteTips.readLongPress), isTrue);
  });
}
