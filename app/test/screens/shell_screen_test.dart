import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/screens/shell_screen.dart';

import '../support/pump_app.dart';

void main() {
  appTest('phone width uses a bottom bar and navigates', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No upcoming'), findsOneWidget);
  });

  appTest('wide width uses a rail with a settings button', (tester) async {
    await pumpApp(tester, size: const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  test('indexFor maps locations', () {
    expect(ShellScreen.indexFor('/today'), 0);
    expect(ShellScreen.indexFor('/upcoming'), 1);
    expect(ShellScreen.indexFor('/lists/abc'), 2);
    expect(ShellScreen.indexFor('/search'), 3);
    expect(ShellScreen.indexFor('/whatever'), 0);
  });
}
