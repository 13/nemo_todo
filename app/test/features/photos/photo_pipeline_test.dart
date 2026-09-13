import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nemo/features/photos/data/photo_pipeline.dart';

void main() {
  Uint8List sourceJpeg({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    // A gradient rather than a flat fill: a flat image survives any resize
    // unchanged, so it would not prove the resize happened.
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    return Uint8List.fromList(img.encodeJpg(image));
  }

  test('a large photo is scaled down to the long edge and re-encoded', () {
    final processed = processPhoto(sourceJpeg(width: 4000, height: 3000))!;
    expect(processed.width, 2048);
    expect(processed.height, 1536);
    expect(processed.bytes.length, lessThan(1024 * 1024));
    expect(processed.sha256, sha256.convert(processed.bytes).toString());
  });

  test('a tall photo is scaled by its own long edge', () {
    final processed = processPhoto(sourceJpeg(width: 1000, height: 4000))!;
    expect(processed.height, 2048);
    expect(processed.width, 512);
  });

  test('a small photo keeps its size but is still re-encoded', () {
    final source = sourceJpeg(width: 100, height: 80);
    final processed = processPhoto(source)!;
    expect(processed.width, 100);
    expect(processed.height, 80);
    // Re-encoded in every case: that is what drops the EXIF block, which
    // is where the camera wrote where the picture was taken.
    expect(processed.sha256, sha256.convert(processed.bytes).toString());
  });

  test('the same bytes always give the same hash', () {
    final source = sourceJpeg(width: 300, height: 200);
    expect(processPhoto(source)!.sha256, processPhoto(source)!.sha256);
  });

  test('bytes that are not an image are refused', () {
    expect(processPhoto(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('orientation is applied before resizing, and EXIF does not survive', () {
    // A landscape image tagged "rotate 90 CW to display": the camera wrote
    // both the fix (orientation) and the leak (make, standing in for the
    // GPS tag and serial number a real phone would add) into the EXIF block.
    final image = img.Image(width: 300, height: 200);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    image.exif.imageIfd.orientation = 6;
    image.exif.imageIfd.make = 'NemoCam';
    final source = Uint8List.fromList(img.encodeJpg(image));

    final processed = processPhoto(source)!;
    // Baked before any resizing decision: the stored long edge is the
    // post-rotation height, not the pre-rotation width.
    expect(processed.width, 200);
    expect(processed.height, 300);

    // hasExif alone would not prove anything -- decoding any JPEG through
    // this package always attaches an ExifData object, empty or not -- so
    // isEmpty is the assertion that actually shows nothing survived.
    final decodedOutput = img.decodeImage(processed.bytes)!;
    expect(decodedOutput.exif.isEmpty, isTrue);
  });
}
