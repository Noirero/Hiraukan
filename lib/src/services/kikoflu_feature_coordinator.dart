import 'dart:async';
import 'dart:io';

import 'audio_conversion_service.dart';
import 'download_path_service.dart';
import 'download_service.dart';
import 'kikoflu_feature_settings.dart';
import 'kikoflu_notification_service.dart';
import 'log_service.dart';

final _log = LogService.instance;

/// Runtime coordinator for KikoFlu-derived opt-in features.
///
/// It intentionally observes Hiraukan's existing download/audio surfaces
/// rather than replacing them, so Unified Sources remains the authority for
/// queue identity, file paths, history, and source resolution.
class KikoFluFeatureCoordinator {
  KikoFluFeatureCoordinator._();
  static final instance = KikoFluFeatureCoordinator._();

  final _settings = KikoFluFeatureSettings.instance;

  StreamSubscription<FileSystemEvent>? _downloadWatch;

  // Debounce each file independently. A single shared debounce causes one WAV
  // finishing to cancel conversion of another WAV that finishes at nearly the
  // same time.
  final Map<String, Timer> _convertDebounces = <String, Timer>{};
  final List<String> _conversionQueue = <String>[];
  final Set<String> _queuedConversions = <String>{};
  final Set<String> _converting = <String>{};
  bool _conversionWorkerRunning = false;
  Timer? _metadataReloadDebounce;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    unawaited(KikoFluNotificationService.instance.initialize());
    await refreshDownloadWatcher();
  }

  Future<void> refreshDownloadWatcher() async {
    await _downloadWatch?.cancel();
    _downloadWatch = null;
    for (final timer in _convertDebounces.values) {
      timer.cancel();
    }
    _convertDebounces.clear();
    _conversionQueue.clear();
    _queuedConversions.clear();
    _metadataReloadDebounce?.cancel();
    _metadataReloadDebounce = null;
    if (!_settings.autoConvertWav) return;

    try {
      final root = await DownloadPathService.getDownloadDirectory();
      if (!await root.exists()) return;
      _downloadWatch = root.watch(recursive: true).listen(
        (event) {
          if (event.isDirectory) return;
          final path = event.path;
          if (!path.toLowerCase().endsWith('.wav')) return;
          _scheduleConversion(path);
        },
        onError: (Object error) {
          _log.warning('Download watcher stopped: $error', tag: 'AudioConv');
        },
      );
    } catch (error) {
      _log.warning('Download watcher unavailable: $error', tag: 'AudioConv');
    }
  }

  void _scheduleConversion(
    String path, {
    Duration delay = const Duration(seconds: 2),
  }) {
    if (!_settings.autoConvertWav) return;
    _convertDebounces.remove(path)?.cancel();
    _convertDebounces[path] = Timer(delay, () {
      _convertDebounces.remove(path);
      _enqueueConversion(path);
    });
  }

  void _enqueueConversion(String path) {
    if (!_settings.autoConvertWav ||
        _converting.contains(path) ||
        !_queuedConversions.add(path)) {
      return;
    }
    _conversionQueue.add(path);
    unawaited(_drainConversionQueue());
  }

  Future<void> _drainConversionQueue() async {
    if (_conversionWorkerRunning) return;
    _conversionWorkerRunning = true;
    try {
      while (_settings.autoConvertWav && _conversionQueue.isNotEmpty) {
        final path = _conversionQueue.removeAt(0);
        _queuedConversions.remove(path);
        await _convertWhenStable(path);
      }
    } finally {
      _conversionWorkerRunning = false;
      if (_settings.autoConvertWav && _conversionQueue.isNotEmpty) {
        unawaited(_drainConversionQueue());
      }
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
      if (first <= 0 || first != second) {
        // The download is still being written. Re-arm only this path rather
        // than losing it or disturbing other completed downloads.
        _scheduleConversion(path);
        return;
      }

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
        _scheduleMetadataReload();
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

  void _scheduleMetadataReload() {
    _metadataReloadDebounce?.cancel();
    _metadataReloadDebounce = Timer(const Duration(milliseconds: 750), () {
      _metadataReloadDebounce = null;
      unawaited(_reloadDownloadMetadata());
    });
  }

  Future<void> _reloadDownloadMetadata() async {
    try {
      await DownloadService.instance.reloadMetadataFromDisk();
    } catch (error) {
      _log.warning(
        'Converted audio is ready but download metadata resync failed: $error',
        tag: 'AudioConv',
      );
    }
  }

  Future<void> dispose() async {
    for (final timer in _convertDebounces.values) {
      timer.cancel();
    }
    _convertDebounces.clear();
    _conversionQueue.clear();
    _queuedConversions.clear();
    _metadataReloadDebounce?.cancel();
    await _downloadWatch?.cancel();
    _initialized = false;
  }
}
