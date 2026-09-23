import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// A note as a row: title, a two-line preview, a pin indicator, tapping
/// through to the note itself. Shared by the notes list and the notes half
/// of search results, which show a note exactly the same way.
class NoteTile extends StatelessWidget {
  const NoteTile({required this.note, required this.keyPrefix, super.key});

  final Note note;

  /// Distinguishes this row's key between the screens that use it, e.g.
  /// `note-tile` on the notes screen and `search-note-tile` in search
  /// results.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final preview = note.body.trim();
    final bodyStyle =
        theme.listTileTheme.subtitleTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle();
    return ListTile(
      key: Key('$keyPrefix-${note.id}'),
      title: Text(note.title),
      subtitle: Text.rich(
        preview.isEmpty
            ? TextSpan(text: l.notePreviewEmpty)
            : markdownPreviewSpan(preview, bodyStyle, theme),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: note.pinned ? const Icon(Icons.push_pin, size: 18) : null,
      onTap: () => context.push(Routes.note(note.id)),
    );
  }
}
