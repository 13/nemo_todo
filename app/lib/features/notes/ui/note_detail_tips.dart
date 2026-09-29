part of 'note_detail_screen.dart';

/// The note page's one-time tips: Make todo, once something is selected,
/// and long press, the first time the read view shows.
mixin _NoteTipsShown on ConsumerState<NoteDetailScreen> {
  MarkdownEditingController get _body;
  FocusNode get _bodyFocus;

  // One-time tips, read from the same KvStore as everything else
  // device-local. Kept for `dispose`'s sake like `_repo`, though nothing
  // here writes after the page is gone.
  late NoteTips _tips;

  // Set as soon as the first non-collapsed selection while focused has
  // been seen, so a flurry of further selection changes -- while
  // `_maybeShowSelectionTip`'s KvStore round trip is still in flight, or
  // once it has answered -- neither ask again nor show the tip twice.
  bool _selectionTipChecked = false;

  void _checkSelectionTip() {
    if (_selectionTipChecked) return;
    if (!_bodyFocus.hasFocus) return;
    final selection = _body.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    // The tip points at the chip, which only shows when the selection has
    // something to make; a selection without leaves the tip for one with.
    if (todoCandidates(_body.value).isEmpty) return;
    _selectionTipChecked = true;
    unawaited(_maybeShowSelectionTip());
  }

  Future<void> _maybeShowSelectionTip() async {
    // Captured before the KvStore round trip, like `_makeTodo` does for its
    // own snackbar: both outlive the `await` that follows.
    final messenger = ScaffoldMessenger.of(context);
    final tip = L.of(context).noteMakeTodoTip;
    if (!await _tips.shouldShow(NoteTips.makeTodo)) return;
    await _tips.markShown(NoteTips.makeTodo);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tip),
          behavior: SnackBarBehavior.floating,
          // Lifted over the format toolbar (48 px) and the chip floating
          // above it, which the tip is about: covering the chip would hide
          // the very thing it points to.
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        ),
      );
  }

  // Set once the read view's first build has asked the KvStore whether to
  // show its hint, so a rebuild -- a sync landing, say -- doesn't ask
  // again. `_showReadHint` only flips true once that answer is yes;
  // closing it flips it back without touching the store again.
  bool _readHintChecked = false;
  bool _showReadHint = false;

  void _checkReadHint() {
    if (_readHintChecked) return;
    _readHintChecked = true;
    unawaited(_maybeShowReadHint());
  }

  Future<void> _maybeShowReadHint() async {
    if (!await _tips.shouldShow(NoteTips.readLongPress)) return;
    // Marked shown as soon as it is decided to show it, not when closed:
    // the point is that it has been seen once, whether or not it is
    // dismissed before the page goes.
    await _tips.markShown(NoteTips.readLongPress);
    if (mounted) setState(() => _showReadHint = true);
  }
}
