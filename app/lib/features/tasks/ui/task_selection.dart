import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_selection.g.dart';

/// The tasks picked while selecting several at once.
///
/// Null when not selecting. An empty set means selecting with nothing
/// picked yet, which is different: the selection bar stays up until the
/// user ends it.
@Riverpod(keepAlive: true)
class TaskSelection extends _$TaskSelection {
  /// The task last toggled, where a shift-click range starts from.
  String? _anchor;

  @override
  Set<String>? build() => null;

  /// Starts selecting with nothing picked. Does nothing if already selecting.
  void start() => state ??= {};

  /// Picks the task if it is not picked, drops it if it is. Starts selecting
  /// if needed, and makes this task the start of the next range.
  void toggle(String id) {
    final picked = {...?state};
    if (!picked.remove(id)) picked.add(id);
    _anchor = id;
    state = picked;
  }

  /// Picks every task from the anchor to [id], inclusive, in the order of
  /// [visibleIds]. What was picked before stays picked.
  ///
  /// With no anchor, [from] stands in for it and becomes the anchor, as the
  /// task open beside the list does for a shift-click before any picking.
  /// With neither, or one that is no longer listed, there is no range to
  /// draw, so this is a plain [toggle].
  void extendTo(String id, List<String> visibleIds, {String? from}) {
    final anchor = _anchor ?? from;
    final start = anchor == null ? -1 : visibleIds.indexOf(anchor);
    final to = visibleIds.indexOf(id);
    if (start < 0 || to < 0) {
      toggle(id);
      return;
    }
    _anchor = anchor;
    final low = start < to ? start : to;
    final high = start < to ? to : start;
    state = {...?state, ...visibleIds.sublist(low, high + 1)};
  }

  /// Drops picked tasks that are no longer listed, such as ones completed
  /// or filtered away. Leaves the state alone, and silent, if none were.
  void retainVisible(Iterable<String> ids) {
    final current = state;
    if (current == null) return;
    final visible = ids.toSet();
    final kept = current.where(visible.contains).toSet();
    if (kept.length != current.length) state = kept;
  }

  /// Stops selecting and forgets the picks and the anchor.
  void end() {
    _anchor = null;
    state = null;
  }
}
