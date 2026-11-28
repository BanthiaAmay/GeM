import 'package:audioplayers/audioplayers.dart';

/// Short UI sounds (the section-complete chime). One shared player, created
/// on first play, so screens never hold a player of their own and a sound
/// that cannot play never breaks a screen.
abstract final class Sounds {
  /// Off under `flutter test`, which has no audio plugin
  /// (see test/flutter_test_config.dart).
  static bool enabled = true;
  static AudioPlayer? _player;

  static Future<void> sectionComplete() async {
    if (!enabled) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.play(AssetSource('sounds/section_complete.mp3'));
    } catch (_) {
      // Muted, unsupported or busy audio: the sound is optional.
    }
  }
}
