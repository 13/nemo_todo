import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/settings/data/data_export.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Where an export goes and an import comes from. Replaced in tests.
abstract interface class DataFiles {
  /// Offers [bytes] to be saved as [name]. False when the user backed out.
  Future<bool> save(String name, Uint8List bytes);

  /// The bytes of a file the user picked, or null when they picked none.
  Future<Uint8List?> open();
}

/// The system's save and open dialogs; a download and an upload on the web.
class PickerDataFiles implements DataFiles {
  const PickerDataFiles();

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: 'application/zip',
      ) !=
      null;

  @override
  Future<Uint8List?> open() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip', 'json'],
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }
}

final dataFilesProvider = Provider<DataFiles>((_) => const PickerDataFiles());

final dataExportProvider = Provider<DataExport>(
  (ref) => DataExport(
    ref.watch(appDatabaseProvider),
    ref.watch(hlcClockProvider),
    ref.watch(photoStoreProvider),
    reminders: ref.watch(reminderSchedulerProvider),
  ),
);

/// Export and import in Settings.
class DataTiles extends ConsumerWidget {
  const DataTiles({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = ref.read(nowProvider)();
    final result = await ref.read(dataExportProvider).export(now: now);
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'nemo-${now.year}-${two(now.month)}-${two(now.day)}.zip';
    final saved = await ref.read(dataFilesProvider).save(name, result.bytes);
    if (saved) _tell(messenger, l.settingsExported);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final bytes = await ref.read(dataFilesProvider).open();
    if (bytes == null) return;
    final String message;
    try {
      final added = await ref.read(dataExportProvider).import(bytes);
      // An export carries its own Inbox, and this device has one too.
      await ref.read(listsRepositoryProvider).mergeDuplicateInboxes();
      message = l.settingsImported(added);
    } on FormatException {
      _tell(messenger, l.settingsImportInvalid);
      return;
    }
    _tell(messenger, message);
  }

  /// Replaces whatever the last export or import said rather than queueing
  /// behind it: an import right after an export should answer at once.
  void _tell(ScaffoldMessengerState messenger, String text) => messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.settingsData),
        ListTile(
          key: const Key('export-data'),
          leading: const Icon(Icons.file_download_outlined),
          title: Text(l.settingsExport),
          subtitle: Text(l.settingsExportHint),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          key: const Key('import-data'),
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(l.settingsImport),
          subtitle: Text(l.settingsImportHint),
          onTap: () => _import(context, ref),
        ),
      ],
    );
  }
}
