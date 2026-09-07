import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';
import 'package:nemo/screens/startup_error_screen.dart';

void main() {
  testWidgets('explains that the database could not be opened', (tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(error: 'TimeoutException after 0:00:15.000000'),
    );
    await tester.pumpAndSettle();

    expect(find.text('nemo cannot open its database'), findsOneWidget);
    expect(find.textContaining('allow it and reload'), findsOneWidget);
    // The cause is shown too: without it there is nothing to report.
    expect(find.textContaining('TimeoutException'), findsOneWidget);
    expect(find.byType(NemoLogoTile), findsOneWidget);
  });
}
