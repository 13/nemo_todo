import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// A note's body in the editor: the markdown field, with the formatting
/// shortcuts and a Make todo entry in its context menu.
class NoteBodyEditor extends StatelessWidget {
  const NoteBodyEditor({
    required this.controller,
    required this.focusNode,
    required this.undoController,
    required this.onInsertLink,
    required this.onMakeTodo,
    super.key,
  });

  final MarkdownEditingController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoController;

  /// The Ctrl/Cmd+K shortcut, shared with the format toolbar's button.
  final VoidCallback onInsertLink;

  /// Makes a todo of what is selected, or of the line under the cursor.
  final VoidCallback onMakeTodo;

  void _apply(TextEditingValue Function(TextEditingValue) command) {
    controller.value = command(controller.value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // Cmd on Apple platforms, Ctrl elsewhere -- binding both everywhere
    // would shadow macOS/iOS's native Ctrl+B / Ctrl+K text-field
    // navigation, which the platform's own text field still wants.
    final useMeta =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyB,
          control: !useMeta,
          meta: useMeta,
        ): () =>
            _apply((v) => toggleInline(v, '**')),
        SingleActivator(
          LogicalKeyboardKey.keyI,
          control: !useMeta,
          meta: useMeta,
        ): () =>
            _apply((v) => toggleInline(v, '_')),
        SingleActivator(
          LogicalKeyboardKey.keyX,
          control: !useMeta,
          meta: useMeta,
          shift: true,
        ): () =>
            _apply((v) => toggleInline(v, '~~')),
        SingleActivator(
          LogicalKeyboardKey.keyK,
          control: !useMeta,
          meta: useMeta,
        ): onInsertLink,
        SingleActivator(
          LogicalKeyboardKey.keyT,
          control: !useMeta,
          meta: useMeta,
          shift: true,
        ): onMakeTodo,
      },
      child: TextField(
        key: const Key('note-body'),
        controller: controller,
        focusNode: focusNode,
        undoController: undoController,
        maxLines: null,
        minLines: 6,
        keyboardType: TextInputType.multiline,
        // Scrolls the line being typed clear of the floating chip, whose
        // top is 56 px above the page's bottom, with a margin -- not just
        // 20 px off the edge, where the chip would cover it.
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [ListContinuationFormatter()],
        contextMenuBuilder: (context, state) {
          final items = [...state.contextMenuButtonItems];
          if (todoCandidates(state.textEditingValue).isNotEmpty) {
            items.insert(
              0,
              ContextMenuButtonItem(
                label: l.noteMakeTodo,
                onPressed: () {
                  state.hideToolbar();
                  onMakeTodo();
                },
              ),
            );
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: state.contextMenuAnchors,
            buttonItems: items,
          );
        },
        decoration: InputDecoration(
          hintText: l.noteBodyHint,
          filled: false,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
