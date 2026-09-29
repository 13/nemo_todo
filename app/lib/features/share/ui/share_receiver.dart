import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/share/data/share_source.dart';
import 'package:nemo/features/share/data/shared_content.dart';
import 'package:nemo/features/share/ui/share_task_sheet.dart';

/// Opens [ShareTaskSheet] for each share from another app: the one that
/// started nemo, once the first frame is up, and any arriving while it
/// runs. A share arriving while a sheet is open waits for it to close
/// rather than stacking a second sheet over the first.
class ShareReceiver extends ConsumerStatefulWidget {
  const ShareReceiver({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// The app's root navigator, which the sheet is shown on: this widget
  /// sits above it, in `MaterialApp.builder`.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<ShareReceiver> createState() => _ShareReceiverState();
}

class _ShareReceiverState extends ConsumerState<ShareReceiver> {
  final _waiting = Queue<SharedContent>();
  StreamSubscription<SharedContent>? _incoming;
  var _showing = false;

  @override
  void initState() {
    super.initState();
    final source = ref.read(shareSourceProvider);
    _incoming = source.incoming.listen(_receive);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final first = await source.initial();
      if (first != null) _receive(first);
    });
  }

  @override
  void dispose() {
    unawaited(_incoming?.cancel());
    super.dispose();
  }

  void _receive(SharedContent content) {
    if (!mounted) return;
    _waiting.add(content);
    unawaited(_showNext());
  }

  Future<void> _showNext() async {
    if (_showing || _waiting.isEmpty) return;
    final context = widget.navigatorKey.currentContext;
    // No navigator yet: the next frame will have one.
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
      return;
    }
    _showing = true;
    final draft = ShareDraft.from(_waiting.removeFirst());
    try {
      await showAppSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ShareTaskSheet(draft: draft),
      );
    } finally {
      _showing = false;
    }
    if (mounted) await _showNext();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
