import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// A note as a card in the notes grid, the way Google Keep shows one: the
/// title, a long preview of the body, the list it belongs to and a pin when
/// it is pinned. Tapping opens the note.
///
/// Keyed `note-tile-<id>`, the key the notes screen's rows had before they
/// were cards, so finders written against the rows still find the card.
class NoteCard extends StatelessWidget {
  const NoteCard({required this.note, this.listName, super.key});

  final Note note;

  /// The name of the note's list, or null when that list is gone.
  final String? listName;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final title = note.title.trim();
    final preview = note.body.trim();
    final bodyStyle = theme.textTheme.bodyMedium ?? const TextStyle();
    return Card.outlined(
      key: Key('note-tile-${note.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.note(note.id)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title.isNotEmpty || note.pinned) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: title.isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (note.pinned)
                      Icon(
                        Icons.push_pin,
                        key: Key('note-card-pin-${note.id}'),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text.rich(
                preview.isEmpty
                    ? TextSpan(text: l.notePreviewEmpty)
                    : markdownPreviewSpan(preview, bodyStyle, theme),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
                style: bodyStyle,
              ),
              if (listName case final name?) ...[
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
