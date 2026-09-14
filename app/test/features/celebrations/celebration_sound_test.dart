import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';

void main() {
  test('the chime ducks other audio instead of taking focus for good', () {
    final android = celebrationAudioContext.android;
    expect(android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);
    // Still media, so the media volume governs it.
    expect(android.usageType, AndroidUsageType.media);
  });
}
