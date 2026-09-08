import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_task.g.dart';

/// The task shown in the pane beside the list on a wide window.
///
/// Null on a phone, where a task is a page of its own and the back button
/// is how you leave it.
@Riverpod(keepAlive: true)
class SelectedTask extends _$SelectedTask {
  @override
  String? build() => null;

  /// A verb rather than a setter: `select(null)` says what it does at the
  /// call site better than assigning null to a property would.
  // ignore: use_setters_to_change_properties
  void select(String? taskId) => state = taskId;
}

/// Opens a task the way the window has room for: in the pane on a wide
/// screen, as a page on a narrow one.
///
/// A task opened by its own URL stays a page even on a wide screen. That is
/// what a link handed to someone should do, and it costs nothing here.
void openTask(BuildContext context, WidgetRef ref, String taskId) {
  if (MediaQuery.sizeOf(context).width >= ShellScreen.splitBreakpoint) {
    ref.read(selectedTaskProvider.notifier).select(taskId);
  } else {
    // The page returns whatever it was popped with; nothing here wants it.
    unawaited(context.push(Routes.task(taskId)));
  }
}
