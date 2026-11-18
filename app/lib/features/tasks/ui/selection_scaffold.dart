import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/tasks/ui/selection_bar.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';

/// A [Scaffold] for a screen whose tasks can be picked several at once.
///
/// While picking, the [SelectionBar] takes the foot of the screen on a
/// phone -- in place of [bottomNavigationBar] and [floatingActionButton] --
/// or [appBar]'s place on a wide window. Starting to pick at the foot puts
/// away the snackbar on show, which would otherwise cover the bar. An
/// [AppBar] given here carries a [SelectTasksButton] among its actions, put
/// there by the screen.
///
/// A selection belongs to the screen it was made on, the newest of these
/// on show. One coming up over another, as a list's page pushed over
/// Today, starts with nothing picked; one going away ends the selection,
/// unless a newer one has come up since and the selection is its own.
class TaskSelectionScaffold extends ConsumerStatefulWidget {
  const TaskSelectionScaffold({
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.enabled = true,
    super.key,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  /// Whether this screen picks tasks at all; without it this is a plain
  /// [Scaffold].
  final bool enabled;

  @override
  ConsumerState<TaskSelectionScaffold> createState() =>
      _TaskSelectionScaffoldState();
}

class _TaskSelectionScaffoldState extends ConsumerState<TaskSelectionScaffold> {
  /// The screens that pick tasks, oldest first; the last owns the
  /// selection.
  static final _live = <_TaskSelectionScaffoldState>[];

  /// Kept from the start: `ref` cannot be read once disposing.
  late final TaskSelection _selection;

  /// Whether this one was counted into [_live], as the widget's `enabled`
  /// decided when it came up.
  var _counted = false;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(taskSelectionProvider.notifier);
    if (!widget.enabled) return;
    final covers = _live.isNotEmpty;
    _live.add(this);
    _counted = true;
    // The screen it came up over keeps its picks to itself. A provider
    // cannot change while the tree builds, so this waits for the frame.
    if (covers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _owns) _selection.end();
      });
    }
  }

  bool get _owns => _live.isNotEmpty && identical(_live.last, this);

  @override
  void dispose() {
    if (_counted) {
      final owned = _owns;
      _live.remove(this);
      // A page popped or replaced goes when its way out has finished; a
      // newer page that began picking in the meantime keeps its picks.
      // Like coming up, this waits for the frame to change the provider.
      if (owned) {
        final selection = _selection;
        WidgetsBinding.instance.addPostFrameCallback((_) => selection.end());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    assert(
      !enabled || _offersSelect(widget.appBar),
      'A screen with taskSelection puts a SelectTasksButton in its '
      "AppBar's actions.",
    );
    if (enabled) {
      ref.listen(taskSelectionProvider, (before, now) {
        // The last action's snackbar, with its Undo, would sit over the
        // bar at the foot for its last few seconds; picking anew is
        // moving on from it.
        if (before == null &&
            now != null &&
            _owns &&
            !SelectionBar.onTop(context)) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    }
    final selecting = enabled && ref.watch(taskSelectionProvider) != null;
    final onTop = selecting && SelectionBar.onTop(context);
    final atFoot = selecting && !onTop;
    const selectionBar = SelectionBar();
    return Scaffold(
      appBar: onTop
          ? const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: selectionBar,
            )
          : widget.appBar,
      body: widget.body,
      bottomNavigationBar: atFoot ? selectionBar : widget.bottomNavigationBar,
      floatingActionButton: atFoot ? null : widget.floatingActionButton,
    );
  }

  /// Whether [bar] has the button that starts picking tasks. The screen
  /// puts it there itself: an [AppBar] cannot be copied with one more
  /// action without losing whatever else was set on it.
  static bool _offersSelect(PreferredSizeWidget? bar) =>
      bar is! AppBar ||
      (bar.actions?.any((a) => a is SelectTasksButton) ?? false);
}
