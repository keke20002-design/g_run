import 'package:flame_audio/flame_audio.dart';

class AudioManager {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    await FlameAudio.audioCache.loadAll([
      'Jump.wav',
      'Anti.wav',
      'Button.wav',
      'Over.wav',
    ]);
    _loaded = true;
  }

  /// Normal gravity restore flip
  static void playFlip() {
    FlameAudio.play('Jump.wav', volume: 0.7);
  }

  /// Entering anti-gravity mode
  static void playAntiGravity() {
    FlameAudio.play('Anti.wav', volume: 0.75);
  }

  /// UI button press
  static void playButton() {
    FlameAudio.play('Button.wav', volume: 0.8);
  }

  static void playGameOver() {
    FlameAudio.play('Over.wav', volume: 0.8);
  }
}
