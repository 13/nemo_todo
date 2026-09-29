import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/today_widget/today_widget_links.dart';

void main() {
  group('widgetRoute', () {
    test('opens Today, a new task, or a task', () {
      expect(widgetRoute(Uri.parse('nemo-widget://today')), '/today');
      expect(widgetRoute(Uri.parse('nemo-widget://add')), widgetAddRoute);
      expect(widgetRoute(Uri.parse('nemo-widget://task/abc')), '/tasks/abc');
    });

    test('opens nothing for a tick or anything else', () {
      expect(widgetRoute(null), isNull);
      expect(widgetRoute(Uri()), isNull);
      expect(widgetRoute(Uri.parse('nemo-widget://tick/abc')), isNull);
      expect(widgetRoute(Uri.parse('nemo-widget://task')), isNull);
      expect(widgetRoute(Uri.parse('https://today')), isNull);
    });

    test('the new-task route is Today asking for the add flow', () {
      final uri = Uri.parse(widgetAddRoute);
      expect(uri.path, '/today');
      expect(uri.queryParameters, contains('new'));
    });
  });

  group('widgetTickedTask', () {
    test('reads the task of a tick', () {
      expect(widgetTickedTask(Uri.parse('nemo-widget://tick/abc')), 'abc');
    });

    test('is null for anything else', () {
      expect(widgetTickedTask(null), isNull);
      expect(widgetTickedTask(Uri.parse('nemo-widget://task/abc')), isNull);
      expect(widgetTickedTask(Uri.parse('nemo-widget://tick')), isNull);
      expect(widgetTickedTask(Uri.parse('other://tick/abc')), isNull);
    });
  });
}
