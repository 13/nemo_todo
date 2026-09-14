import 'package:nemo/features/celebrations/data/celebration_sound.dart';

/// Counts what would have played.
class RecordingCelebrationSound implements CelebrationSound {
  int plays = 0;

  @override
  Future<void> play() async => plays++;
}
