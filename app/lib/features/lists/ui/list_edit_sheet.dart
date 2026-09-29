import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// Creates or edits a list. Returns the saved list, or null when dismissed.
Future<TaskList?> showListEditSheet(BuildContext context, {TaskList? list}) =>
    showAppSheet<TaskList>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ListEditSheet(list: list),
    );

class ListEditSheet extends ConsumerStatefulWidget {
  const ListEditSheet({this.list, super.key});

  final TaskList? list;

  @override
  ConsumerState<ListEditSheet> createState() => _ListEditSheetState();
}

class _ListEditSheetState extends ConsumerState<ListEditSheet> {
  late final _name = TextEditingController(text: widget.list?.name ?? '');
  late int _color = widget.list?.color ?? 0;
  late String _icon = widget.list?.icon ?? 'list';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(listsRepositoryProvider);
    final TaskList saved;
    if (widget.list == null) {
      saved = await repo.create(name: name, color: _color, icon: _icon);
    } else {
      saved = widget.list!.copyWith(name: name, color: _color, icon: _icon);
      await repo.save(saved);
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final nemo = context.nemoColors;
    final scheme = Theme.of(context).colorScheme;
    final colorNames = [
      l.colorTeal,
      l.colorBlue,
      l.colorPurple,
      l.colorPink,
      l.colorRed,
      l.colorOrange,
      l.colorGreen,
      l.colorGrey,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.list == null ? l.listsNewList : l.listsEditList,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('list-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l.listsName,
              hintText: l.listsNameHint,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text(l.listsColor, style: Theme.of(context).textTheme.labelLarge),
          // Each disc sits in a finger's 48 px; neighbouring targets share
          // the gap between discs, and the nudge gives back the 8 px the
          // first reaches past its disc, so the discs stay where they were.
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Wrap(
              spacing: -6,
              children: [
                for (var i = 0; i < nemo.listPalette.length; i++)
                  Semantics(
                    label: colorNames[i],
                    selected: _color == i,
                    inMutuallyExclusiveGroup: true,
                    button: true,
                    child: InkResponse(
                      key: Key('list-color-$i'),
                      onTap: () => setState(() => _color = i),
                      radius: 22,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: nemo.listColor(i),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == i
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: _color == i
                              ? AppIcon(
                                  Icons.check,
                                  size: 18,
                                  // White on a deep colour, black on a light one:
                                  // dark themes' palettes are pastels.
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                            nemo.listColor(i),
                                          ) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(l.listsIcon, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in listIconChoices.entries)
                if (entry.key != 'inbox' || widget.list?.isInbox == true)
                  ChoiceChip(
                    key: Key('list-icon-${entry.key}'),
                    label: AppIcon(entry.value, size: 20),
                    // Names the icon, for a screen reader and a pointer.
                    tooltip: l.listIconName(entry.key),
                    selected: _icon == entry.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _icon = entry.key),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('list-save'),
                onPressed: _save,
                child: Text(l.commonSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
