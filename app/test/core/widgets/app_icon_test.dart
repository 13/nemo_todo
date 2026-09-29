import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/app_icon.dart';

void main() {
  Future<IconData?> drawn(
    WidgetTester tester,
    AppStyle style,
    IconData icon,
  ) async {
    await tester.pumpWidget(
      // A fresh app per style: one app handed a new theme animates to it.
      MaterialApp(
        key: ValueKey(style),
        theme: AppTheme.build(style, Brightness.light),
        home: AppIcon(icon),
      ),
    );
    return tester.widget<Icon>(find.byType(Icon)).icon;
  }

  testWidgets('only the macOS style swaps the icon set', (tester) async {
    for (final style in [AppStyle.nemo, AppStyle.material]) {
      expect(await drawn(tester, style, Icons.today), Icons.today);
    }
    final mac = await drawn(tester, AppStyle.macos, Icons.settings_outlined);
    expect(mac?.fontFamily, 'PhosphorRegular');
    // The selected destination is filled, as Apple fills its own.
    expect(
      (await drawn(tester, AppStyle.macos, Icons.today))?.fontFamily,
      'PhosphorFill',
    );
    // The list's "Sort by" and the chevron of a row that opens a page.
    for (final icon in [Icons.sort_rounded, Icons.chevron_right_rounded]) {
      expect(
        (await drawn(tester, AppStyle.macos, icon))?.fontFamily,
        'PhosphorRegular',
      );
    }
    // One with no counterpart stays Material's rather than vanishing.
    expect(await drawn(tester, AppStyle.macos, Icons.ac_unit), Icons.ac_unit);
  });
}
