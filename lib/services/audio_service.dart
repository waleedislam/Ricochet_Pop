import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The distinct sound effects the game plays.
enum SfxSound { shoot, pop, floatBonus, win, lose, tap, danger }

/// Centralized sound-effect playback with a persisted mute preference.
///
/// A small round-robin pool is used for `pop`/`floatBonus` so that rapid,
/// overlapping pops (e.g. a big chain reaction) don't cut each other off,
/// while one-shot sounds (shoot, tap, win, lose) each get their own player.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _muteKey = 'bouncing_rush_muted';
  static const int _popPoolSize = 4;

  bool _muted = false;
  bool get muted => _muted;

  bool _ready = false;
  bool get ready => _ready;

  final List<AudioPlayer> _popPool = [];
  int _popIndex = 0;

  AudioPlayer? _shootPlayer;
  AudioPlayer? _winPlayer;
  AudioPlayer? _losePlayer;
  AudioPlayer? _tapPlayer;
  AudioPlayer? _dangerPlayer;

  static const Map<SfxSound, String> _assets = {
    SfxSound.shoot: 'sounds/shoot.wav',
    SfxSound.pop: 'sounds/pop.wav',
    SfxSound.floatBonus: 'sounds/bonus.wav',
    SfxSound.win: 'sounds/win.wav',
    SfxSound.lose: 'sounds/lose.wav',
    SfxSound.tap: 'sounds/tap.wav',
    SfxSound.danger: 'sounds/danger.wav',
  };

  /// Sets up the player pool and loads the saved mute preference. Safe to
  /// call multiple times — later calls are a no-op. Call once, early,
  /// e.g. from the game screen's `initState`.
  Future<void> init() async {
    if (_ready) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_muteKey) ?? false;

      for (int i = 0; i < _popPoolSize; i++) {
        final p = AudioPlayer(playerId: 'sfx_pop_$i');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        _popPool.add(p);
      }

      _shootPlayer = await _makePlayer('sfx_shoot');
      _tapPlayer = await _makePlayer('sfx_tap');
      _dangerPlayer = await _makePlayer('sfx_danger');
      // Win/lose are a little longer, so they don't need low-latency mode.
      _winPlayer = AudioPlayer(playerId: 'sfx_win')
        ..setReleaseMode(ReleaseMode.stop);
      _losePlayer = AudioPlayer(playerId: 'sfx_lose')
        ..setReleaseMode(ReleaseMode.stop);

      _ready = true;
    } catch (_) {
      // Sound is an enhancement, not a requirement. If the platform audio
      // plugin isn't available for any reason (still starting up, missing
      // on this platform, or simply not registered — as under
      // `flutter test`), keep the game fully playable with sound
      // disabled instead of crashing or hanging startup.
      _ready = false;
    }
  }

  Future<AudioPlayer> _makePlayer(String id) async {
    final p = AudioPlayer(playerId: id);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setPlayerMode(PlayerMode.lowLatency);
    return p;
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_muteKey, value);
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  /// Plays [sound]. Silently does nothing if muted or not yet initialized
  /// (so call sites never need to guard this themselves).
  Future<void> play(SfxSound sound, {double volume = 1.0}) async {
    if (_muted || !_ready) return;
    final asset = _assets[sound]!;
    final source = AssetSource(asset);

    try {
      switch (sound) {
        case SfxSound.pop:
        case SfxSound.floatBonus:
          final player = _popPool[_popIndex];
          _popIndex = (_popIndex + 1) % _popPool.length;
          await player.stop();
          await player.setVolume(volume);
          await player.play(source);
          break;
        case SfxSound.shoot:
          await _shootPlayer?.stop();
          await _shootPlayer?.setVolume(volume);
          await _shootPlayer?.play(source);
          break;
        case SfxSound.tap:
          await _tapPlayer?.stop();
          await _tapPlayer?.setVolume(volume);
          await _tapPlayer?.play(source);
          break;
        case SfxSound.danger:
          await _dangerPlayer?.stop();
          await _dangerPlayer?.setVolume(volume * 0.6);
          await _dangerPlayer?.play(source);
          break;
        case SfxSound.win:
          await _winPlayer?.setVolume(volume);
          await _winPlayer?.play(source);
          break;
        case SfxSound.lose:
          await _losePlayer?.setVolume(volume);
          await _losePlayer?.play(source);
          break;
      }
    } catch (_) {
      // Playback failures (e.g. platform audio not ready yet) shouldn't
      // ever crash gameplay — sound is an enhancement, not a requirement.
    }
  }

  Future<void> dispose() async {
    for (final p in _popPool) {
      await p.dispose();
    }
    _popPool.clear();
    await _shootPlayer?.dispose();
    await _winPlayer?.dispose();
    await _losePlayer?.dispose();
    await _tapPlayer?.dispose();
    await _dangerPlayer?.dispose();
    _ready = false;
  }
}
