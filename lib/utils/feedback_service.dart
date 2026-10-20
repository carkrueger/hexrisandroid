import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

enum GameSound { place, clear, combo, gameOver }

class FeedbackService {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _init;

  /// Audio setup for short game sound effects:
  ///
  /// * Mix with other apps instead of taking audio focus. By default
  ///   audioplayers on Android requests focus, which would pause the user's
  ///   music on every piece placement. On iOS this adds the `mixWithOthers`
  ///   option to the playback category.
  /// * Android usage "game" / content "sonification", so the system routes and
  ///   ducks the effects like any other game audio.
  static final AudioContext _audioContext =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
          .build()
          .copy(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.none,
            ),
          );

  /// Configures the global audio context and the effects player. Called from
  /// main(); safe to call more than once.
  static Future<void> init() => _init ??= _configure();

  static Future<void> _configure() async {
    try {
      await AudioPlayer.global.setAudioContext(_audioContext);
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android keeps a context per player too; iOS only has the global one.
        await _player.setAudioContext(_audioContext);
      }
      // SoundPool on Android: low latency for the short wav effects in
      // assets/sounds/. A no-op on iOS, which has a single player mode.
      await _player.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      // Sound is optional; never let audio setup stop the game from starting.
      debugPrint('FeedbackService: audio setup failed: $e');
    }
  }

  static Future<void> _playSound(GameSound sound) async {
    if (!Storage.soundEnabled) return;
    await init();
    final String asset;
    switch (sound) {
      case GameSound.place:
        asset = 'sounds/place.wav';
      case GameSound.clear:
        asset = 'sounds/clear.wav';
      case GameSound.combo:
        asset = 'sounds/combo.wav';
      case GameSound.gameOver:
        asset = 'sounds/gameover.wav';
    }
    await _player.play(AssetSource(asset));
  }

  static void _haptic(GameSound sound) {
    if (!Storage.hapticsEnabled) return;
    switch (sound) {
      case GameSound.place:
        HapticFeedback.lightImpact();
      case GameSound.clear:
        HapticFeedback.mediumImpact();
      case GameSound.combo:
        HapticFeedback.heavyImpact();
      case GameSound.gameOver:
        HapticFeedback.vibrate();
    }
  }

  static void trigger(GameSound sound) {
    _playSound(sound);
    _haptic(sound);
  }
}
