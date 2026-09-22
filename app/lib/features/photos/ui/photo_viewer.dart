import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// Opens the parent's pictures full screen, starting at [index].
Future<void> showPhotoViewer(
  BuildContext context, {
  required PhotoParent parentKind,
  required String parentId,
  required int index,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _PhotoViewer(
      parentKind: parentKind,
      parentId: parentId,
      initialIndex: index,
    ),
    fullscreenDialog: true,
  ),
);

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({
    required this.parentKind,
    required this.parentId,
    required this.initialIndex,
  });

  final PhotoParent parentKind;
  final String parentId;
  final int initialIndex;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final photos =
        ref
            .watch(photosByParentProvider(widget.parentKind, widget.parentId))
            .value ??
        const [];
    // The last picture deleted leaves nothing to look at.
    if (photos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    final current = _index.clamp(0, photos.isEmpty ? 0 : photos.length - 1);
    return Scaffold(
      key: const Key('photo-viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${current + 1} / ${photos.length}'),
        actions: [
          IconButton(
            key: const Key('photo-viewer-delete'),
            tooltip: l.commonDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: photos.isEmpty
                ? null
                : () => ref
                      .read(photosRepositoryProvider)
                      .delete(photos[current].id),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: PhotoThumbnail(
              sha256: photos[i].sha256,
              size: MediaQuery.sizeOf(context).width,
              radius: 0,
            ),
          ),
        ),
      ),
    );
  }
}
