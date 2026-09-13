import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// A picture ready to be stored and uploaded.
class ProcessedPhoto {
  const ProcessedPhoto({
    required this.bytes,
    required this.sha256,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String sha256;
  final int width;
  final int height;
}

/// Turns whatever the camera or the file picker gave us into the one shape
/// nemo stores: a JPEG no larger than [maxEdge] on its long side.
///
/// Everything is re-encoded, including a picture already small enough. The
/// encode is what drops the EXIF block, and a phone writes the location and
/// the camera's serial number into it -- neither of which should travel to
/// a server, let alone to everyone a list is shared with.
///
/// Returns null for bytes that are not an image this build can read.
ProcessedPhoto? processPhoto(
  Uint8List raw, {
  int maxEdge = 2048,
  int quality = 85,
}) {
  // Some decoders in this package throw on malformed or too-short input
  // rather than returning null (e.g. a PSD header read past a 4-byte
  // buffer), so bytes this build merely fails to read must be caught too.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(raw);
  } on Object {
    return null;
  }
  if (decoded == null) return null;
  // Orientation is an EXIF tag, and dropping EXIF without applying it first
  // would turn every portrait photo on its side. bakeOrientation only
  // clears the tag it just applied, though -- it carries every other EXIF
  // entry (GPS, camera serial, ...) forward onto the baked image, and
  // copyResize below would carry it forward again, so drop the whole block
  // ourselves right after, before it reaches the encoder.
  final upright = img.bakeOrientation(decoded)..exif = img.ExifData();
  final longest = upright.width > upright.height
      ? upright.width
      : upright.height;
  final scaled = longest <= maxEdge
      ? upright
      : img.copyResize(
          upright,
          width: upright.width >= upright.height ? maxEdge : null,
          height: upright.height > upright.width ? maxEdge : null,
          interpolation: img.Interpolation.average,
        );
  final bytes = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
  return ProcessedPhoto(
    bytes: bytes,
    sha256: sha256.convert(bytes).toString(),
    width: scaled.width,
    height: scaled.height,
  );
}
