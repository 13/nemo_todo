import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/core/widgets/quick_add_bar.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/screens/shell_screen.dart';

/// The Material style's way to add a task, as Android's own apps add
/// things: a floating "New task" button opening a sheet with the quick-add
/// field in it, the keyboard already up. The field reads the same shorthand
/// as the bar the other styles keep at the foot of the screen.
///
/// On a wide window the rail's button asks instead (through the same signal
/// as the keyboard's N), so this one stays out of sight there.
class NewTaskButton extends ConsumerStatefulWidget {
  const NewTaskButton({
    required this.listId,
    this.defaultDueAt,
    this.showListPicker = false,
    super.key,
  });

  final String? listId;
  final int? defaultDueAt;
  final bool showListPicker;

  @override
  ConsumerState<NewTaskButton> createState() => _NewTaskButtonState();
}

class _NewTaskButtonState extends ConsumerState<NewTaskButton> {
  late final ValueNotifier<int> _requests = ref.read(
    quickAddFocusRequestsProvider,
  );

  /// Whether the sheet is up, so a second request does not stack another.
  var _open = false;

  @override
  void initState() {
    super.initState();
    _requests.addListener(_openSheet);
  }

  @override
  void dispose() {
    _requests.removeListener(_openSheet);
    super.dispose();
  }

  void _openSheet() {
    if (_open || !mounted) return;
    _open = true;
    unawaited(
      showAppSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: QuickAddBar(
            key: const Key('new-task-sheet'),
            listId: widget.listId,
            defaultDueAt: widget.defaultDueAt,
            showListPicker: widget.showListPicker,
            inSheet: true,
            onAdded: () => Navigator.pop(sheet),
          ),
        ),
      ).whenComplete(() => _open = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= ShellScreen.railBreakpoint) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton.extended(
      key: const Key('new-task'),
      onPressed: _openSheet,
      icon: const AppIcon(Icons.add_rounded),
      label: Text(L.of(context).shortcutNewTask),
    );
  }
}
