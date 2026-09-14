import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/widgets/section_header.dart';

void main() {
  testWidgets('a long title wraps instead of overflowing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: SectionHeader(
              title: 'A section title far too long for one line',
              count: 3,
              collapsed: false,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
