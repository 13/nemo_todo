import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// One picture at a fixed size, or a placeholder while this device does
/// not hold its bytes.
///
/// A placeholder rather than a spinner: a photo taken on another device
/// and not fetched yet is a normal state, not a thing in progress, and a
/// list of spinners reads as a broken screen. The same placeholder covers
/// every other state that is not a clean set of bytes -- still loading, or
/// a failed fetch -- since none of those are the user's problem to see
/// spelled out on a thumbnail.
class PhotoThumbnail extends ConsumerWidget {
  const PhotoThumbnail({
    required this.sha256,
    required this.size,
    this.radius = 10,
    super.key,
  });

  final String sha256;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    // `.value` never throws: on error, with no earlier data, it is null,
    // same as loading -- one placeholder covers both.
    final bytes = ref.watch(photoBytesProvider(sha256)).value;
    final pending =
        ref.watch(pendingPhotoHashesProvider).value?.contains(sha256) ?? false;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes == null)
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_outlined,
                  size: size / 2.5,
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
            if (pending)
              Positioned(
                left: 2,
                bottom: 2,
                child: Semantics(
                  label: l.photosNotUploaded,
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: size / 4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
