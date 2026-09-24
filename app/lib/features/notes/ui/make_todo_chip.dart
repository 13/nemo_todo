import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Turns the browser's own context menu on (`true`) or off (`false`).
typedef ContextMenuToggle = void Function({required bool enabled});

/// What [setBrowserContextMenuEnabled] calls. Replaced in tests, where
/// `kIsWeb` is always false and the real toggle would do nothing to see.
@visibleForTesting
ContextMenuToggle browserContextMenuToggle = _toggleBrowserContextMenu;

void _toggleBrowserContextMenu({required bool enabled}) {
  // Only the web has a browser menu that stands in for Flutter's own.
  if (!kIsWeb) return;
  unawaited(
    enabled
        ? BrowserContextMenu.enableContextMenu()
        : BrowserContextMenu.disableContextMenu(),
  );
}

/// On the web, a right-click in a text field opens the browser's menu,
/// which knows nothing of "Make todo". Turned off while the note body has
/// focus, so Flutter's own menu -- with that item -- shows instead.
void setBrowserContextMenuEnabled({required bool enabled}) =>
    browserContextMenuToggle(enabled: enabled);

/// "Make todo" for selected text -- or "Open task" for a cursor on a line
/// already linked to one -- right where the text is being edited, for
/// people who never find the toolbar button or the selection menu item.
/// Nothing at all when neither applies.
class MakeTodoChip extends StatelessWidget {
  const MakeTodoChip({
    required this.controller,
    required this.onMakeTodo,
    required this.onOpenTask,
    super.key,
  });

  final TextEditingController controller;

  /// Turns what the cursor or selection is on into a task.
  final VoidCallback onMakeTodo;

  /// Opens the task linked on the cursor's line.
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.value;
        // Only a cursor opens a task, as in the format toolbar, since a
        // selection starting on a linked line can still reach lines to make
        // tasks of. Unlike the toolbar, only a selection offers Make todo:
        // a chip popping up on every list line being typed would be noise,
        // and the toolbar button still covers the cursor case.
        final linkedTask =
            value.selection.isValid && value.selection.isCollapsed
            ? linkedTaskAt(value.text, value.selection.start)
            : null;
        final Widget chip;
        if (linkedTask != null) {
          chip = _chip(
            Icons.open_in_new,
            l.noteOpenTask,
            () => onOpenTask(linkedTask),
          );
        } else if (!value.selection.isCollapsed &&
            todoCandidates(value).isNotEmpty) {
          chip = _chip(Icons.add_task, l.noteMakeTodo, onMakeTodo);
        } else {
          return const SizedBox.shrink();
        }
        // Part of editing the body, not a tap outside it: on web and
        // desktop a click outside a field unfocuses it, which would hide
        // this chip -- and lose the selection's focus -- mid-click.
        return TextFieldTapRegion(child: chip);
      },
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onPressed) =>
      ActionChip(
        key: const Key('note-make-todo-chip'),
        avatar: Icon(icon),
        label: Text(label),
        elevation: 2,
        onPressed: onPressed,
      );
}
