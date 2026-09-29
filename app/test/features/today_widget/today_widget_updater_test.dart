import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';
import 'package:nemo/features/today_widget/today_widget_updater.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_widget_bridge.dart';
import '../../support/test_db.dart';

void main() {
  final task = Task(
    id: 't1',
    listId: 'l',
    title: 'Milk',
    sortKey: 'a',
    updatedAt: 'x',
    dueAt: testNow.millisecondsSinceEpoch,
  );

  test('saves the tasks and redraws', () async {
    final bridge = FakeWidgetBridge();
    await TodayWidgetUpdater(bridge).pushTasks([task], testNow);
    expect(bridge.taskIds, ['t1']);
    expect(bridge.redraws, 1);
  });

  test('skips a push identical to the last', () async {
    final bridge = FakeWidgetBridge();
    final updater = TodayWidgetUpdater(bridge);
    await updater.pushTasks([task], testNow);
    await updater.pushTasks([task], testNow);
    await updater.pushLook({'mode': 'dark'});
    await updater.pushLook({'mode': 'dark'});
    expect(bridge.savesOf(WidgetKeys.tasks), 1);
    expect(bridge.savesOf(WidgetKeys.look), 1);
    expect(bridge.redraws, 2);

    await updater.pushTasks([], testNow);
    expect(bridge.taskIds, isEmpty);
    expect(bridge.redraws, 3);
  });

  test('a failing widget is swallowed and tried again next time', () async {
    final bridge = FakeWidgetBridge()..failSave = true;
    final updater = TodayWidgetUpdater(bridge);
    await updater.pushTasks([task], testNow);
    expect(bridge.redraws, 0);
    bridge.failSave = false;
    await updater.pushTasks([task], testNow);
    expect(bridge.taskIds, ['t1']);
  });
}
