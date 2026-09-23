import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';
import 'package:nemo/features/notes/ui/markdown/read_lines.dart';

/// A note body as formatted text, markers hidden: the read half of the
/// note screen's toggle.
///
/// Writes nothing itself. A tapped checkbox hands the flipped body to
/// [onChanged]; a tap anywhere else on a line asks to edit there through
/// [onEditAt]; a long-press hands the line to [onLongPressLine].
class NoteReadView extends StatefulWidget {
  const NoteReadView({
    required this.body,
    required this.onChanged,
    required this.onEditAt,
    required this.onLongPressLine,
    required this.onOpenLink,
    this.taskChip,
    super.key,
  });

  final String body;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onEditAt;
  final void Function(int lineStart, Offset globalPosition) onLongPressLine;
  final ValueChanged<String> onOpenLink;
  final Widget Function(String taskId)? taskChip;

  @override
  State<NoteReadView> createState() => _NoteReadViewState();
}

class _NoteReadViewState extends State<NoteReadView> {
  // Recognisers made for the last build's links; disposed on the next
  // build and on dispose, as a TextSpan does not own them.
  final _recognizers = <GestureRecognizer>[];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  GestureRecognizer _recognizer(String url) {
    final r = TapGestureRecognizer()..onTap = () => widget.onOpenLink(url);
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final c = theme.colorScheme;
    final body = widget.body;
    final lines = readLines(body);

    InlineSpan inline(ReadLine line, TextStyle style) => markdownSpan(
      body.substring(line.contentStart, line.end),
      style,
      theme,
      linkRecognizer: _recognizer,
      taskChip: widget.taskChip,
    );

    Widget rich(ReadLine line, TextStyle style) =>
        Text.rich(inline(line, style), style: style);

    final base = t.bodyLarge ?? const TextStyle();
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final indent = line.level * 8.0;
      final content = switch (line.kind) {
        ReadKind.blank => const SizedBox(height: 8),
        ReadKind.rule => const Divider(),
        ReadKind.text => rich(line, base),
        ReadKind.heading => rich(
          line,
          (switch (line.level) {
                    1 => t.headlineSmall,
                    2 => t.titleLarge,
                    3 => t.titleMedium,
                    _ => t.titleSmall,
                  } ??
                  base)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        ReadKind.quote => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.outlineVariant, width: 3)),
          ),
          child: rich(
            line,
            base.copyWith(
              fontStyle: FontStyle.italic,
              color: c.onSurfaceVariant,
            ),
          ),
        ),
        ReadKind.bullet || ReadKind.numbered => Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  line.kind == ReadKind.bullet ? '•' : line.marker,
                  style: base.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              Expanded(child: rich(line, base)),
            ],
          ),
        ),
        ReadKind.task => Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            children: [
              Checkbox(
                key: Key('read-check-$i'),
                value: line.checked,
                visualDensity: VisualDensity.compact,
                onChanged: (_) =>
                    widget.onChanged(toggleTaskAt(body, line.start)),
              ),
              Expanded(
                child: rich(
                  line,
                  line.checked
                      ? base.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: c.onSurfaceVariant,
                        )
                      : base,
                ),
              ),
            ],
          ),
        ),
        ReadKind.codeBlock => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              body
                  .substring(line.contentStart, line.end)
                  .replaceFirst(RegExp(r'\n\s*```.*$'), ''),
              style: base.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New', 'Courier'],
              ),
            ),
          ),
        ),
      };
      children.add(
        GestureDetector(
          key: Key('read-line-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onEditAt(line.start),
          onLongPressStart: (d) =>
              widget.onLongPressLine(line.start, d.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: content,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
