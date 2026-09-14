import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Brief, ducking audio focus: someone's music or podcast dips under the
/// chime and carries on afterwards, rather than being stopped by it. The web
/// has no audio focus and ignores it.
final AudioContext celebrationAudioContext = AudioContextConfig(
  focus: AudioContextConfigFocus.duckOthers,
).build();

/// Plays the sound for a big moment.
abstract interface class CelebrationSound {
  Future<void> play();
}

/// Plays the bundled chime, and never throws: a device that cannot play it
/// still gets its task ticked off.
class AssetCelebrationSound implements CelebrationSound {
  AssetCelebrationSound({@visibleForTesting AudioPlayer Function()? newPlayer})
    : _newPlayer = newPlayer ?? AudioPlayer.new;

  final AudioPlayer Function() _newPlayer;
  AudioPlayer? _player;
  var _disposed = false;

  @override
  Future<void> play() async {
    if (_disposed) return;
    try {
      final player = _player ??= _newPlayer();
      // Asked for with every play, so no chime ever takes full focus.
      await player.play(
        AssetSource('sounds/celebrate.mp3'),
        volume: 0.6,
        ctx: celebrationAudioContext,
      );
    } on Object catch (error) {
      debugPrint('Celebration sound failed: $error');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _player?.dispose();
    _player = null;
  }
}

/// Overridden in tests: the plugin has no implementation there.
final celebrationSoundProvider = Provider<CelebrationSound>((ref) {
  final sound = AssetCelebrationSound();
  ref.onDispose(() => unawaited(sound.dispose()));
  return sound;
});
