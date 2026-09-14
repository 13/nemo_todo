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

  test('every chime asks for the ducking focus', () async {
    final player = _RecordingPlayer(failSetAudioContext: true);
    final sound = AssetCelebrationSound(newPlayer: () => player);

    await sound.play();
    await sound.play();

    expect(player.playContexts, [
      celebrationAudioContext,
      celebrationAudioContext,
    ]);
  });
}

/// Records what each play asked for; setting the context on its own throws,
/// as a platform call can.
class _RecordingPlayer extends Fake implements AudioPlayer {
  _RecordingPlayer({required this.failSetAudioContext});

  final bool failSetAudioContext;
  final playContexts = <AudioContext?>[];

  @override
  Future<void> setAudioContext(AudioContext ctx) async {
    if (failSetAudioContext) throw StateError('no audio focus');
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async => playContexts.add(ctx);

  @override
  Future<void> dispose() async {}
}
