import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/notes_screen.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('the notes destination lists notes grouped by list', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '500 g flour');
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('500 g flour'), findsOneWidget);
    expect(find.byType(NotesScreen), findsOneWidget);
  });

  testWidgets('with no notes the empty state says so', (tester) async {
    await pumpApp(tester, initialLocation: '/notes');
    await tester.pumpAndSettle();

    expect(find.textContaining('No notes yet'), findsOneWidget);
  });

  testWidgets('tapping a note opens it', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-title')), findsOneWidget);
  });
}
