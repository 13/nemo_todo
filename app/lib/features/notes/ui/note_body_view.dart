import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;

/// A note's body, drawn.
///
/// The stored text is markdown source and stays that way: this only
/// decides how it looks. `MarkdownBody`'s default extension set already
/// covers the shapes a note needs -- headings, emphasis, lists, links,
/// inline code, code blocks and quotes -- and renders raw HTML as inert
/// text rather than markup, so nothing extra has to be turned off here.
class NoteBodyView extends ConsumerWidget {
  const NoteBodyView({required this.body, super.key});

  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MarkdownBody(
    data: body,
    selectable: true,
    // Same launcher About uses, so this test-doubles the same way and a
    // household never has an in-app note quietly open `file:` or
    // `mailto:` links, let alone something a note's markdown made up.
    onTapLink: (text, href, title) {
      if (href == null) return;
      final uri = Uri.tryParse(href);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        return;
      }
      unawaited(ref.read(openUrlProvider)(uri));
    },
  );
}
