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

  group('un-deleting', () {
    const deleted = '0000000000002-0000-a';
    final tombstone = _t(deleted, deletedAt: deleted);

    test('a restore with a newer stamp beats the tombstone', () {
      final restored = _t('0000000000003-0000-b');
      expect(incomingWins(tombstone, restored), isTrue);
      expect(
        incomingWins(restored, tombstone),
        isFalse,
        reason: 'the tombstone arriving late does not undo the restore',
      );
    });

    test('a delete made after the restore beats it', () {
      final restored = _t('0000000000003-0000-b');
      const again = '0000000000004-0000-a';
      expect(incomingWins(restored, _t(again, deletedAt: again)), isTrue);
    });

    test('an erased tombstone wins although it says it is the oldest', () {
      final erased = _t('0000000000005-0000-b', deletedAt: erasedStamp('b'));
      expect(incomingWins(tombstone, erased), isTrue);
      expect(incomingWins(_t('0000000000003-0000-a'), erased), isTrue);
      expect(erased.isDeleted, isTrue);
    });
  });

  group('the tombstone window', () {
    final now = DateTime.utc(2026, 9, 29, 12);
    String deletedAgo(Duration ago) => Hlc(
      millis: now.subtract(ago).millisecondsSinceEpoch,
      counter: 3,
      node: 'dev',
    ).toString();

    test('is thirty days', () {
      expect(tombstoneRetention, const Duration(days: 30));
    });

    test('takes in what was deleted within it and nothing older', () {
      final cutoff = tombstoneCutoff(now);
      expect(
        deletedAgo(const Duration(days: 29)).compareTo(cutoff),
        greaterThanOrEqualTo(0),
      );
      expect(
        deletedAgo(const Duration(days: 31)).compareTo(cutoff),
        lessThan(0),
      );
      expect(erasedStamp('dev').compareTo(cutoff), lessThan(0));
    });

    test('can be measured over another length', () {
      final week = tombstoneCutoff(now, retention: const Duration(days: 7));
      expect(deletedAgo(const Duration(days: 8)).compareTo(week), lessThan(0));
    });
  });
}
