import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_menu.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// The keyboard, for a window with one: single keys, as mail and task apps
/// on the web use, since a browser keeps Ctrl and ⌘ with a digit or N for
/// its own tabs and windows and never lets the page see them.
///
/// None of them fire while a text field has the keyboard, so typing an N
/// in a title types an N.
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({required this.onGo, required this.child, super.key});

  /// Goes to the shell's destination at an index, 0 to 4.
  final ValueChanged<int> onGo;

  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  /// Whether a text field has the keyboard, which keeps every key its own.
  /// The focused node is the field's own `Focus`, inside its EditableText.
  static bool get _typing =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;

  /// [action] when nobody is typing; otherwise the key goes on its way.
  KeyEventResult Function() _unlessTyping(VoidCallback action) => () {
    if (_typing) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  };

  void _step(int by) {
    final tasks = ref.read(visibleTasksProvider).value;
    if (tasks.isEmpty) return;
    final selected = ref.read(selectedTaskProvider);
    final at = tasks.indexWhere((t) => t.id == selected);
    final next = at < 0
        ? (by > 0 ? 0 : tasks.length - 1)
        : (at + by).clamp(0, tasks.length - 1);
    openTask(context, ref, tasks[next].id);
  }

  /// The selected task, if it is still one the screen lists.
  void _withSelected(void Function(Task task) action) {
    final id = ref.read(selectedTaskProvider);
    final task = ref
        .read(visibleTasksProvider)
        .value
        .where((t) => t.id == id)
        .firstOrNull;
    if (task != null) action(task);
  }

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, KeyEventResult Function()>{
      const SingleActivator(LogicalKeyboardKey.keyN): _unlessTyping(
        () => ref.read(quickAddFocusRequestsProvider).value++,
      ),
      const SingleActivator(LogicalKeyboardKey.slash): _unlessTyping(
        () => widget.onGo(4),
      ),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _unlessTyping(() => widget.onGo(4)),
      const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _unlessTyping(
        () => widget.onGo(4),
      ),
      for (final (i, key) in const [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ].indexed)
        SingleActivator(key): _unlessTyping(() => widget.onGo(i)),
      const SingleActivator(LogicalKeyboardKey.comma): _unlessTyping(
        () => unawaited(context.push(Routes.settings)),
      ),
      const SingleActivator(LogicalKeyboardKey.arrowDown): _unlessTyping(
        () => _step(1),
      ),
      const SingleActivator(LogicalKeyboardKey.keyJ): _unlessTyping(
        () => _step(1),
      ),
      const SingleActivator(LogicalKeyboardKey.arrowUp): _unlessTyping(
        () => _step(-1),
      ),
      const SingleActivator(LogicalKeyboardKey.keyK): _unlessTyping(
        () => _step(-1),
      ),
      const SingleActivator(LogicalKeyboardKey.space): _unlessTyping(
        () => _withSelected(
          (t) => unawaited(completeTask(ref, t, done: !t.done)),
        ),
      ),
      const SingleActivator(LogicalKeyboardKey.delete): _unlessTyping(
        () => _withSelected(
          (t) => unawaited(deleteTaskWithUndo(context, ref, t)),
        ),
      ),
      const SingleActivator(LogicalKeyboardKey.backspace): _unlessTyping(
        () => _withSelected(
          (t) => unawaited(deleteTaskWithUndo(context, ref, t)),
        ),
      ),
      const SingleActivator(LogicalKeyboardKey.escape): _unlessTyping(
        () => ref.read(selectedTaskProvider.notifier).select(null),
      ),
      const SingleActivator(LogicalKeyboardKey.slash, shift: true):
          _unlessTyping(() => unawaited(showShortcutsHelp(context))),
    };
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        for (final MapEntry(key: activator, value: run) in bindings.entries) {
          if (activator.accepts(event, HardwareKeyboard.instance)) {
            return run();
          }
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

/// Lists the keyboard shortcuts; the question mark opens it, and Settings
/// links to it on a window wide enough to have a keyboard.
Future<void> showShortcutsHelp(BuildContext context) {
  final l = L.of(context);
  final rows = [
    ('N', l.shortcutNewTask),
    ('/', l.navSearch),
    ('1 – 5', l.shortcutGoTo),
    ('↑ ↓   J K', l.shortcutMove),
    ('Space', l.shortcutToggle),
    ('Delete', l.shortcutDelete),
    ('Esc', l.shortcutClose),
    (',', l.navSettings),
    ('?', l.shortcutHelp),
  ];
  return showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        title: Text(l.shortcutsTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, what) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          keys,
                          style: text.labelLarge?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      Expanded(child: Text(what, style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonClose),
          ),
        ],
      );
    },
  );
}
