import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'log_service.dart';

final _log = LogService.instance;

/// Manages crossfade (fade in / fade out) transitions for the audio player.
/// Kept as an isolated optional layer so the existing Hiraukan playback plan
/// and Unified Sources queue remain authoritative when crossfade is disabled.
class AudioCrossfadeManager {
  final AudioPlayer _player;

  Duration _crossfadeDuration = Duration.zero;
  double _originalVolume = 1.0;
  bool _isCrossfading = false;
  bool _crossfadeCancelled = false;

  AudioCrossfadeManager(this._player);

  Duration get crossfadeDuration => _crossfadeDuration;
  bool get isCrossfading => _isCrossfading;

  Future<void> setCrossfadeDuration(Duration duration) async {
    _crossfadeDuration = duration;
    _log.info(
      'Crossfade duration set to: ${duration.inMilliseconds}ms',
      tag: 'Audio',
    );
  }

  Future<void> fadeOut() async {
    if (_crossfadeDuration <= Duration.zero || _crossfadeCancelled) return;
    _crossfadeCancelled = false;
    _isCrossfading = true;
    _originalVolume = _player.volume;

    final steps =
        (_crossfadeDuration.inMilliseconds / 50).round().clamp(1, 100);
    final stepMs =
        (_crossfadeDuration.inMilliseconds / steps).round().clamp(10, 100);
    final volStep = _originalVolume / steps;

    for (var i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      if (_crossfadeCancelled) return;
      await _player.setVolume(
        (_originalVolume - volStep * i).clamp(0.0, _originalVolume),
      );
    }
    if (!_crossfadeCancelled) {
      await _player.setVolume(0.0);
      _isCrossfading = false;
    }
  }

  Future<void> fadeIn() async {
    if (_crossfadeDuration <= Duration.zero || _crossfadeCancelled) {
      _isCrossfading = false;
      return;
    }
    _crossfadeCancelled = false;

    final steps =
        (_crossfadeDuration.inMilliseconds / 50).round().clamp(1, 100);
    final stepMs =
        (_crossfadeDuration.inMilliseconds / steps).round().clamp(10, 100);
    final volStep = _originalVolume / steps;

    await _player.setVolume(0.0);
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      if (_crossfadeCancelled) return;
      await _player.setVolume((volStep * i).clamp(0.0, _originalVolume));
    }
    if (!_crossfadeCancelled) await _player.setVolume(_originalVolume);
    _isCrossfading = false;
  }

  void cancel() {
    if (!_isCrossfading) return;
    _crossfadeCancelled = true;
    _player.setVolume(_originalVolume);
    _isCrossfading = false;
  }

  Future<bool> crossfadeTo(Future<void> Function() loadAndPlay) async {
    if (_crossfadeDuration <= Duration.zero) return false;
    await fadeOut();
    if (_crossfadeCancelled) return false;
    await loadAndPlay();
    await fadeIn();
    return true;
  }
}
