import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/l10n/app_localizations.dart';

/// Whether a note may open [url]: web links only, so a note never quietly
/// opens `file:`, `mailto:` or `javascript:` -- the same rule the rendered
/// view used to apply.
bool isWebLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
}

/// Asks for a URL and links the selection to it. Cancelling changes no
/// text, but still hands focus back to [focusNode]. The dialog takes
/// focus from the body; the controller keeps its selection, so the insert
/// still lands where it was.
///
/// [focusNode], when given, is refocused -- on cancel as well, so the
/// toolbar and keyboard don't vanish -- before the edit is written: the
/// dialog leaves the body unfocused, and writing to an unfocused field
/// means no debounce save fires and a sync could overwrite the insert
/// before the user ever notices.
///
/// A focus request only takes effect on the next microtask -- [FocusNode]
/// batches focus changes and applies them together -- so
/// [FocusManager.applyFocusChangesIfNeeded] forces it through immediately.
/// Without that, `controller.value` below would still be written while
/// [focusNode] reports itself unfocused, and any listener deciding "was
/// this a real edit?" by that flag right now would get it wrong.
Future<void> promptForLink(
  BuildContext context,
  TextEditingController controller, {
  FocusNode? focusNode,
}) async {
  final url = await showDialog<String>(
    context: context,
    builder: (context) => const _LinkDialog(),
  );
  // The dialog can outlive whatever opened it -- the note it's editing can
  // be deleted, or its page popped, while the dialog still sits on top.
  // [context] is checked for exactly that: once it's gone, [focusNode] and
  // [controller] are gone with it, and touching either would throw.
  if (!context.mounted) return;
  // Refocused whether or not a URL came back: a cancelled dialog must not
  // leave the body unfocused, taking the toolbar and keyboard with it.
  focusNode?.requestFocus();
  FocusManager.instance.applyFocusChangesIfNeeded();
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) return;
  controller.value = insertLink(controller.value, trimmed);
}

/// The link dialog's own [TextEditingController] must outlive
/// [showDialog]'s return: the dialog is still animating out when it pops,
/// so a controller disposed right after the pop would be used while the
/// exit transition builds. A [StatefulWidget] disposes it only once the
/// dialog has actually left the tree.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text(l.mdLink),
      content: TextField(
        key: const Key('md-link-url'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(hintText: l.mdLinkUrlHint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          key: const Key('md-link-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('md-link-ok'),
          onPressed: () => Navigator.pop(context, _field.text),
          child: Text(l.mdLink),
        ),
      ],
    );
  }
}

/// Formatting buttons for a note body, shown above the keyboard while the
/// body has focus. Every button is one [TextEditingValue] edit, so the
/// field's undo takes it back in one step.
class NoteFormatToolbar extends ConsumerWidget {
  const NoteFormatToolbar({
    required this.controller,
    required this.undoController,
    required this.onInsertLink,
    super.key,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;

  /// Opens the link dialog and, on a URL, wraps the selection in a link.
  ///
  /// Handed in rather than called directly: this toolbar is shown only
  /// while the body has focus -- built by a caller (see `NoteDetailScreen`)
  /// that swaps it for nothing the instant that focus is lost, and the link
  /// dialog's own field takes that focus the moment it opens. By the time
  /// the dialog closes, this toolbar's own [BuildContext] (and any
  /// [FocusNode] it might hold) is already unmounted on the ordinary,
  /// successful path -- not only when the screen itself is gone. The
  /// caller's own callback closes over its own, longer-lived context and
  /// focus node instead.
  final VoidCallback onInsertLink;

  void _apply(TextEditingValue Function(TextEditingValue) command) {
    controller.value = command(controller.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);

    Widget button(
      String key,
      IconData icon,
      String tooltip,
      VoidCallback? onPressed,
    ) => IconButton(
      key: Key(key),
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );

    // A click here is part of editing the body, not a tap outside it: on
    // web and desktop a mouse click outside a field unfocuses it, which
    // would hide this bar mid-click.
    return TextFieldTapRegion(
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 48,
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, undoController]),
              builder: (context, _) {
                final link = linkAtCursor(controller.value);
                final undo = undoController.value;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    button(
                      'md-undo',
                      Icons.undo,
                      l.mdUndo,
                      undo.canUndo ? undoController.undo : null,
                    ),
                    button(
                      'md-redo',
                      Icons.redo,
                      l.mdRedo,
                      undo.canRedo ? undoController.redo : null,
                    ),
                    button(
                      'md-bold',
                      Icons.format_bold,
                      l.mdBold,
                      () => _apply((v) => toggleInline(v, '**')),
                    ),
                    button(
                      'md-italic',
                      Icons.format_italic,
                      l.mdItalic,
                      () => _apply((v) => toggleInline(v, '_')),
                    ),
                    button(
                      'md-strike',
                      Icons.format_strikethrough,
                      l.mdStrike,
                      () => _apply((v) => toggleInline(v, '~~')),
                    ),
                    button(
                      'md-heading',
                      Icons.title,
                      l.mdHeading,
                      () => _apply(cycleHeading),
                    ),
                    button(
                      'md-bullet',
                      Icons.format_list_bulleted,
                      l.mdBulletList,
                      () => _apply((v) => toggleLinePrefix(v, '- ')),
                    ),
                    button(
                      'md-numbered',
                      Icons.format_list_numbered,
                      l.mdNumberedList,
                      () => _apply((v) => toggleLinePrefix(v, '1. ')),
                    ),
                    button(
                      'md-checkbox',
                      Icons.check_box_outlined,
                      l.mdChecklist,
                      () => _apply(toggleCheckbox),
                    ),
                    button(
                      'md-quote',
                      Icons.format_quote,
                      l.mdQuote,
                      () => _apply((v) => toggleLinePrefix(v, '> ')),
                    ),
                    button(
                      'md-code',
                      Icons.code,
                      l.mdCode,
                      () => _apply((v) => toggleInline(v, '`')),
                    ),
                    button(
                      'md-code-block',
                      Icons.data_object,
                      l.mdCodeBlock,
                      () => _apply(toggleCodeBlock),
                    ),
                    button('md-link', Icons.link, l.mdLink, onInsertLink),
                    // Contextual, and only shown while the cursor sits in a
                    // web link: last, like every other button -- its own
                    // test scrolls the bar to reach it.
                    if (link != null && isWebLink(link))
                      button(
                        'md-open-link',
                        Icons.open_in_new,
                        l.mdOpenLink,
                        () => unawaited(
                          ref.read(openUrlProvider)(Uri.parse(link)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
