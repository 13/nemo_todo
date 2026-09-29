/// The URIs the Today widget sends, built the same way in
/// `TodayWidgetProvider.kt`: `nemo-widget://today`, `nemo-widget://add`,
/// `nemo-widget://task/<id>` and `nemo-widget://tick/<id>`.
library;

const widgetScheme = 'nemo-widget';

/// Where Today goes when the widget asks for a new task. `NemoApp` sees
/// the query, goes to Today and asks for the quick-add field.
const widgetAddRoute = '/today?new';

/// The app route a tap on the widget opens, or null for a URI that opens
/// nothing (a tick, or one from something else). Routes are spelled out so
/// this file does not pull in the router and every screen with it.
String? widgetRoute(Uri? uri) {
  if (uri == null || uri.scheme != widgetScheme) return null;
  return switch ((uri.host, uri.pathSegments)) {
    ('today', []) => '/today',
    ('add', []) => widgetAddRoute,
    ('task', [final id]) when id.isNotEmpty => '/tasks/$id',
    _ => null,
  };
}

/// The task a tap on a widget row's circle ticks off, or null.
String? widgetTickedTask(Uri? uri) {
  if (uri == null || uri.scheme != widgetScheme || uri.host != 'tick') {
    return null;
  }
  return switch (uri.pathSegments) {
    [final id] when id.isNotEmpty => id,
    _ => null,
  };
}
