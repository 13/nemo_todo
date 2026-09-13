import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A tiny real JPEG, so the pipeline has something it can decode.
Uint8List smallJpeg({int width = 20, int height = 16}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x % 256, y % 256, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}
