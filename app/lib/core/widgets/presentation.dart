import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/screens/style_adaptation.dart';

/// Whether [context] is a Mac window: the macOS style, with room for its
/// sidebar. A phone-sized window in the macOS style is drawn as iOS.
bool isMacWindow(BuildContext context) =>
    context.appStyle == AppStyle.macos && !StyleAdaptation.isPhone(context);

/// A sheet as the window shows one: on a Mac, a panel dropping from the top
/// of the window; elsewhere, Material's sheet rising from the bottom.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
}) {
  if (!isMacWindow(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: showDragHandle,
      builder: builder,
    );
  }
  final scheme = Theme.of(context).colorScheme;
  final nemo = context.nemoColors;
  final raised = Theme.of(context).bottomSheetTheme.backgroundColor;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    pageBuilder: (context, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: DecoratedBox(
              decoration: _floating(14),
              child: Material(
                color: raised ?? scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: nemo.separator, width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  // A sheet's content is laid out for the bottom, where the
                  // keyboard and the home bar push up; up here, neither does.
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: builder(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// The soft, wide shadow a Mac window casts under a floating panel: a
/// blurred shadow of its own, not Material's elevation.
BoxDecoration _floating(double radius) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  boxShadow: const [
    BoxShadow(color: Color(0x2E000000), blurRadius: 28, offset: Offset(0, 10)),
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
  ],
);

/// A day picked as the window picks one: on a Mac, a calendar in a popover
/// beside what asked, taken at a click; elsewhere, Material's dialog.
Future<DateTime?> pickDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (!isMacWindow(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }
  // Beside whatever asked: below it where there is room, above where not.
  // Measured against the root overlay, where the popover is shown: a
  // shell's own navigator starts to the right of its sidebar.
  final overlay =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()!
          as RenderBox;
  final box = context.findRenderObject() as RenderBox?;
  final anchor = box == null
      ? Rect.fromCenter(
          center: overlay.size.center(Offset.zero),
          width: 0,
          height: 0,
        )
      : box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  const size = Size(304, 336);
  final below = anchor.bottom + 6 + size.height <= overlay.size.height;
  final top = below
      ? anchor.bottom + 6
      : (anchor.top - 6 - size.height).clamp(8.0, double.infinity);
  final left = anchor.left.clamp(
    8.0,
    (overlay.size.width - size.width - 8).clamp(8.0, double.infinity),
  );
  final nemo = context.nemoColors;
  final raised = Theme.of(context).popupMenuTheme.color;
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, _, _) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: _floating(12),
            child: Material(
              key: const Key('date-popover'),
              color: raised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: nemo.separator, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: CalendarDatePicker(
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: lastDate,
                onDateChanged: (day) => Navigator.pop(context, day),
              ),
            ),
          ),
        ),
      ],
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// A group of settings rows: on a Mac, an inset rounded panel with a
/// hairline between the rows, as System Settings draws its forms;
/// elsewhere, the rows as they are.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (context.appStyle == AppStyle.material) return _android(context);
    if (context.appStyle != AppStyle.macos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      // A Material, not a painted box: the rows' highlights are drawn on
      // the nearest one, and a fill between would hide them.
      child: Material(
        color: light ? const Color(0x08000000) : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: nemo.separator, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme.merge(
          shape: const RoundedRectangleBorder(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0)
                  Divider(height: 0.5, indent: 16, color: nemo.separator),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on SettingsGroup {
  /// Android 16's Settings: each row a tile of its own, a hair apart, the
  /// group's outer corners fully round and the inner ones barely.
  Widget _android(BuildContext context) {
    final tile = Theme.of(context).colorScheme.surfaceContainerHigh;
    const outer = Radius.circular(24);
    const inner = Radius.circular(6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 2),
            Material(
              color: tile,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? outer : inner,
                  bottom: i == children.length - 1 ? outer : inner,
                ),
              ),
              child: ListTileTheme.merge(
                shape: const RoundedRectangleBorder(),
                child: child,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A context-menu row as the window draws one: on a Mac, dense and plain,
/// its label alone, as a Mac menu is; elsewhere, Material's row with its
/// icon.
PopupMenuItem<T> menuItem<T>(
  BuildContext context, {
  required T value,
  required IconData icon,
  required String label,
  Color? color,
}) {
  if (context.appStyle == AppStyle.macos) {
    return PopupMenuItem(
      value: value,
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
  return PopupMenuItem(
    value: value,
    child: Row(
      children: [
        AppIcon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    ),
  );
}

/// The line between groups of [menuItem]s, as thin as the window's.
PopupMenuEntry<T> menuDivider<T>(BuildContext context) =>
    PopupMenuDivider(height: context.appStyle == AppStyle.macos ? 9 : 16);

/// A settings row's icon: in the Material style on a tonal circle, as
/// Android's Settings draws its own; elsewhere the icon as it is.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (context.appStyle != AppStyle.material) return AppIcon(icon);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: AppIcon(icon, size: 20, color: scheme.onPrimaryContainer),
    );
  }
}
