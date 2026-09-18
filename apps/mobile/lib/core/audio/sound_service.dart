import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// The small set of short, synthesized SFX under assets/sounds/ — there's no
/// real card artwork/audio budget yet, so these are simple generated tones
/// (see the generator script used to produce them), just enough to make taps
/// and round outcomes feel responsive rather than silent.
enum GameSound { tap, roundWin, roundLose, tie, victory, defeat }

const _assetPaths = {
  GameSound.tap: 'assets/sounds/tap.wav',
  GameSound.roundWin: 'assets/sounds/round_win.wav',
  GameSound.roundLose: 'assets/sounds/round_lose.wav',
  GameSound.tie: 'assets/sounds/tie.wav',
  GameSound.victory: 'assets/sounds/victory.wav',
  GameSound.defeat: 'assets/sounds/defeat.wav',
};

/// One preloaded AudioPlayer per effect, reused via seek-to-zero+play so
/// repeated triggers don't pay asset-decode latency each time. Sound is
/// purely cosmetic here — every failure is swallowed so a missing/broken
/// asset or a platform audio hiccup never breaks gameplay.
class SoundService {
  final Map<GameSound, AudioPlayer> _players = {};
  final Map<GameSound, Future<void>> _loading = {};
  bool muted = false;

  Future<void> _ensureLoaded(GameSound sound) {
    return _loading.putIfAbsent(sound, () async {
      final player = AudioPlayer();
      await player.setAsset(_assetPaths[sound]!);
      _players[sound] = player;
    });
  }

  void preloadAll() {
    for (final sound in GameSound.values) {
      unawaited(_ensureLoaded(sound).catchError((_) {}));
    }
  }

  Future<void> play(GameSound sound) async {
    if (muted) return;
    try {
      await _ensureLoaded(sound);
      final player = _players[sound];
      if (player == null) return;
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Best-effort only.
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
  }
}

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService()..preloadAll();
  ref.onDispose(service.dispose);
  return service;
});
