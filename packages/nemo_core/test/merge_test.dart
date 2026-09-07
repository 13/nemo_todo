import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

Task _t(String updatedAt, {String? deletedAt}) => Task(
  id: 't',
  listId: 'l',
  title: 'x',
  sortKey: 'V',
  updatedAt: updatedAt,
  deletedAt: deletedAt,
);

void main() {
  test('incoming wins when local is absent', () {
    expect(incomingWins(null, _t('0000000000001-0000-a')), isTrue);
  });

  test('higher HLC wins', () {
    expect(
      incomingWins(_t('0000000000001-0000-a'), _t('0000000000002-0000-a')),
      isTrue,
    );
    expect(
      incomingWins(_t('0000000000002-0000-a'), _t('0000000000001-0000-a')),
      isFalse,
    );
  });

  test('equal HLC keeps local (idempotent replay)', () {
    expect(
      incomingWins(_t('0000000000001-0000-a'), _t('0000000000001-0000-a')),
      isFalse,
    );
  });

  test('same millis and counter: higher node id wins', () {
    expect(
      incomingWins(_t('0000000000001-0000-a'), _t('0000000000001-0000-b')),
      isTrue,
    );
  });

  test('a tombstone is just a newer row', () {
    expect(
      incomingWins(
        _t('0000000000001-0000-a'),
        _t('0000000000002-0000-a', deletedAt: '0000000000002-0000-a'),
      ),
      isTrue,
    );
  });
}
