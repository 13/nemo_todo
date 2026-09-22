import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photo_viewer.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// The pictures on a task or a note, with a button to add another.
class PhotoStrip extends ConsumerStatefulWidget {
  const PhotoStrip({
    required this.parentKind,
    required this.parentId,
    super.key,
  });

  final PhotoParent parentKind;
  final String parentId;

  @override
  ConsumerState<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends ConsumerState<PhotoStrip> {
  static const _size = 72.0;

  // Decoding and re-encoding a camera photo can take a couple of seconds;
  // disabling the button is the only sign of that this screen needs, since
  // a thumbnail never shows a spinner.
  var _adding = false;

  Future<void> _add(BuildContext context, ImageSource source) async {
    final l = L.of(context);
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    // The strip may be gone by the time a large file finishes reading --
    // e.g. the user backed out of the task while it was still loading.
    if (!mounted) return;
    setState(() => _adding = true);
    try {
      final photo = await ref
          .read(photosRepositoryProvider)
          .add(widget.parentKind, widget.parentId, bytes);
      if (photo == null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.photosNotAnImage)));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _pick(BuildContext context) async {
    final l = L.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.photosTakePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              key: const Key('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.photosChoose),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && context.mounted) await _add(context, source);
  }

  /// What the server said when it would not take a picture. A code this
  /// build does not recognise -- a future server, an older client talking
  /// to a newer one -- says nothing rather than printing itself raw.
  String? _refusal(L l, String? code) => switch (code) {
    'blob_too_large' => l.photosTooLarge,
    'quota_exceeded' => l.photosServerFull,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final photos =
        ref
            .watch(photosByParentProvider(widget.parentKind, widget.parentId))
            .value ??
        const [];
    final refusal = _refusal(
      l,
      ref.watch(syncEngineProvider.select((s) => s.photoError)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (refusal != null)
          Padding(
            key: const Key('photo-refusal'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              refusal,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SizedBox(
          key: const Key('task-photos'),
          height: _size,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // A picture has no text of its own, so a screen reader
                  // would announce an unnamed button without this.
                  child: Semantics(
                    button: true,
                    label: l.photosPhoto(i + 1, photos.length),
                    child: InkWell(
                      key: Key('photo-${photos[i].id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showPhotoViewer(
                        context,
                        parentKind: widget.parentKind,
                        parentId: widget.parentId,
                        index: i,
                      ),
                      child: PhotoThumbnail(
                        sha256: photos[i].sha256,
                        size: _size,
                      ),
                    ),
                  ),
                ),
              SizedBox.square(
                dimension: _size,
                child: OutlinedButton(
                  key: const Key('photo-add'),
                  onPressed: _adding ? null : () => unawaited(_pick(context)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Tooltip(
                    message: l.photosAdd,
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
