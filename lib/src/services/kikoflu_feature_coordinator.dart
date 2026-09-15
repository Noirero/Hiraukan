import 'dart:async';
import 'dart:io';

import 'audio_conversion_service.dart';
import 'audio_player_service.dart';
import 'download_path_service.dart';
import 'download_service.dart';
import 'hi_res_audio_service.dart';
import 'kikoflu_feature_settings.dart';
import 'kikoflu_notification_service.dart';
import 'log_service.dart';

final _log = LogService.instance;

/// Runtime coordinator for KikoFlu-derived opt-in features.
///
/// It intentionally observes Hiraukan's existing playback/download surfaces
/// rather than replacing them, so Unified Sources remains the authority for
/// queue identity, file paths, history, and source resolution.
class KikoFluFeatureCoordinator {
  KikoFluFeatureCoordinator._();
  static final instance = KikoFluFeatureCoordinator._();

  final _settings = KikoFluFeatureSettings.instance;
  final _player = AudioPlayerService.instance;

  StreamSubscription<FileSystemEvent>? _downloadWatch;
  StreamSubscription? _trackWatch;
  StreamSubscription<Duration>? _positionWatch;
  StreamSubscription<Duration?>? _durationWatch;
  Timer? _convertDebounce;
  final Set<String> _converting = <String>{};

  Duration? _duration;
  String? _trackId;
  bool _fading = false;
  double _transitionBaseVolume = 1;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    unawaited(KikoFluNotificationService.instance.initialize());
    if (_settings.hiResEnabled) {
      unawaited(HiResAudioService.instance.setEnabled(true));
    }

    _trackWatch = _player.currentTrackStream.listen((track) {
      final changed = track?.id != _trackId;
      _trackId = track?.id;
      if (changed && _settings.crossfadeEnabled) {
        unawaited(_fadeInAfterTrackChange());
      }
    });
    _durationWatch = _player.durationStream.listen((value) => _duration = value);
    _positionWatch = _player.positionStream.listen(_onPosition);

    await refreshDownloadWatcher();
  }

  Future<void> refreshDownloadWatcher() async {
    await _downloadWatch?.cancel();
    _downloadWatch = null;
    _convertDebounce?.cancel();
    _convertDebounce = null;
    if (!_settings.autoConvertWav) return;

    try {
      final root = await DownloadPathService.getDownloadDirectory();
      if (!await root.exists()) return;
      _downloadWatch = root.watch(recursive: true).listen(
        (event) {
          final path = event.path;
          if (!path.toLowerCase().endsWith('.wav')) return;
          _convertDebounce?.cancel();
          _convertDebounce = Timer(const Duration(seconds: 2), () {
            unawaited(_convertWhenStable(path));
          });
        },
        onError: (Object error) {
          _log.warning('Download watcher stopped: $error', tag: 'AudioConv');
        },
      );
    } catch (error) {
      _log.warning('Download watcher unavailable: $error', tag: 'AudioConv');
    }
  }

  Future<void> _convertWhenStable(String path) async {
    if (!_settings.autoConvertWav || _converting.contains(path)) return;
    final file = File(path);
    if (!await file.exists()) return;
    _converting.add(path);
    try {
      final first = await file.length();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!await file.exists()) return;
      final second = await file.length();
      if (first <= 0 || first != second) return;

      final format = WavConversionFormat.fromValue(_settings.conversionFormat);
      if (!AudioConversionService.instance.isSupported(format)) {
        _log.warning(
          'Selected conversion format is unavailable on this platform: ${format.displayName}',
          tag: 'AudioConv',
        );
        return;
      }

      final converted = await AudioConversionService.instance.convert(
        path,
        format,
        onProgress: (progress) {
          unawaited(KikoFluNotificationService.instance.showProgress(
            id: path.hashCode,
            title: 'Converting audio',
            body: File(path).uri.pathSegments.last,
            progress: (progress * 100).round(),
            maxProgress: 100,
          ));
        },
      );
      if (converted != null) {
        // KikoFlu updated its own download metadata directly. Hiraukan has a
        // richer local/offline metadata pipeline, so rescan through that
        // existing authority instead of duplicating or rewriting its schema.
        try {
          await DownloadService.instance.reloadMetadataFromDisk();
        } catch (error) {
          _log.warning(
            'Converted audio is ready but download metadata resync failed: $error',
            tag: 'AudioConv',
          );
        }
        await KikoFluNotificationService.instance.showMessage(
          id: path.hashCode,
          title: 'Audio conversion complete',
          body: File(converted).uri.pathSegments.last,
        );
      }
    } finally {
      _converting.remove(path);
    }
  }

  void _onPosition(Duration position) {
    if (!_settings.crossfadeEnabled || _fading || !_player.playing) return;
    final duration = _duration;
    if (duration == null || duration <= Duration.zero) return;
    final fade = Duration(milliseconds: _settings.crossfadeMs);
    final remaining = duration - position;
    if (remaining <= Duration.zero || remaining > fade) return;
    // Hiraukan currently keeps the logical user volume private inside the
    // player service. Imported crossfade therefore uses unity only while the
    // user explicitly opts in; normal playback is never modified by default.
    _transitionBaseVolume = 1;
    unawaited(_fadeOut(fade));
  }

  Future<void> _fadeOut(Duration duration) async {
    if (_fading) return;
    _fading = true;
    final steps = (duration.inMilliseconds ~/ 50).clamp(4, 80);
    try {
      for (var i = 1; i <= steps; i++) {
        if (!_settings.crossfadeEnabled) break;
        await Future<void>.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
        await _player.setVolume(
          (_transitionBaseVolume * (1 - i / steps)).clamp(0.0, 1.0),
        );
      }
    } catch (error) {
      _log.warning('Crossfade fade-out interrupted: $error', tag: 'Audio');
    } finally {
      _fading = false;
    }
  }

  Future<void> _fadeInAfterTrackChange() async {
    final target = _transitionBaseVolume.clamp(0.0, 1.0);
    final duration = Duration(milliseconds: _settings.crossfadeMs);
    final steps = (duration.inMilliseconds ~/ 50).clamp(4, 80);
    try {
      await _player.setVolume(0);
      for (var i = 1; i <= steps; i++) {
        if (!_settings.crossfadeEnabled) break;
        await Future<void>.delayed(
          Duration(milliseconds: duration.inMilliseconds ~/ steps),
        );
        await _player.setVolume((target * i / steps).clamp(0.0, 1.0));
      }
      await _player.setVolume(target);
    } catch (error) {
      _log.warning('Crossfade fade-in interrupted: $error', tag: 'Audio');
    }
  }

  Future<void> dispose() async {
    _convertDebounce?.cancel();
    await _downloadWatch?.cancel();
    await _trackWatch?.cancel();
    await _positionWatch?.cancel();
    await _durationWatch?.cancel();
    _initialized = false;
  }
}
