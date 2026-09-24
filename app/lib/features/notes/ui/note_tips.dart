import 'package:flutter/material.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Whether a one-time hint has already been shown on this device, and
/// recording that it has -- so it never shows again.
///
/// Backed by [KvStore], like every other per-device preference: the tips
/// are about this device having seen the hint once, not a property of any
/// note or account that would need to sync.
class NoteTips {
  NoteTips(this._kv);

  final KvStore _kv;

  /// First non-collapsed selection made in a note body.
  static const makeTodo = 'tips.noteMakeTodo';

  /// First time a note opens in the read view.
  static const readLongPress = 'tips.noteReadLongPress';

  /// True until [markShown] has been called for [key] on this device.
  Future<bool> shouldShow(String key) async => await _kv.get(key) != '1';

  /// Records that the hint at [key] has been shown, so [shouldShow] never
  /// answers true for it again.
  Future<void> markShown(String key) => _kv.set(key, '1');
}

/// The read view's one-time hint: "long-press a line to make it a todo",
/// dismissible with a close button. Sits above `NoteReadView` until closed.
class ReadViewHint extends StatelessWidget {
  const ReadViewHint({required this.onClose, super.key});

  /// Called when the close button is tapped; the caller decides how to
  /// stop showing it (this widget holds no state of its own).
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    return Container(
      key: const Key('note-read-hint'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.noteReadLongPressHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            key: const Key('note-read-hint-close'),
            icon: const Icon(Icons.close),
            tooltip: l.commonClose,
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
