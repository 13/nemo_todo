import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// Creates or edits a list. Returns the saved list, or null when dismissed.
Future<TaskList?> showListEditSheet(BuildContext context, {TaskList? list}) =>
    showModalBottomSheet<TaskList>(
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (var i = 0; i < nemo.listPalette.length; i++)
                InkResponse(
                  key: Key('list-color-$i'),
                  onTap: () => setState(() => _color = i),
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
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                    label: Icon(entry.value, size: 20),
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
