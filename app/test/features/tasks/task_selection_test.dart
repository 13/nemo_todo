import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';

void main() {
  late ProviderContainer container;
  late TaskSelection selection;

  Set<String>? state() => container.read(taskSelectionProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    selection = container.read(taskSelectionProvider.notifier);
  });

  const ids = ['a', 'b', 'c', 'd', 'e'];

  test('start gives an empty set and end gives null', () {
    expect(state(), isNull);
    selection.start();
    expect(state(), <String>{});
    selection.end();
    expect(state(), isNull);
  });

  test('toggle starts selecting, and deselecting the last id keeps it on', () {
    selection.toggle('a');
    expect(state(), {'a'});
    selection.toggle('a');
    expect(state(), <String>{});
  });

  test('extendTo selects the range downward from the anchor', () {
    selection
      ..toggle('b')
      ..extendTo('d', ids);
    expect(state(), {'b', 'c', 'd'});
  });

  test('extendTo selects the range upward and adds to the selection', () {
    selection
      ..toggle('b')
      ..extendTo('a', ids);
    expect(state(), {'a', 'b'});
  });

  test('extendTo without an anchor behaves as toggle', () {
    selection.extendTo('c', ids);
    expect(state(), {'c'});
  });

  test('extendTo with an anchor not in the list behaves as toggle', () {
    selection
      ..toggle('z')
      ..extendTo('c', ids);
    expect(state(), {'z', 'c'});
  });

  test('end clears the anchor', () {
    selection
      ..toggle('b')
      ..end()
      ..extendTo('d', ids);
    expect(state(), {'d'});
  });

  test('retainVisible drops ids that are no longer listed', () {
    selection
      ..toggle('a')
      ..toggle('b')
      ..retainVisible(['a']);
    expect(state(), {'a'});
  });

  test('retainVisible does nothing when not selecting', () {
    selection.retainVisible(['a']);
    expect(state(), isNull);
  });

  test('retainVisible does not notify when nothing was dropped', () {
    selection
      ..toggle('a')
      ..toggle('b');
    var notified = 0;
    container.listen(taskSelectionProvider, (_, _) => notified++);
    selection.retainVisible(['a', 'b', 'c']);
    expect(notified, 0);
  });
}
