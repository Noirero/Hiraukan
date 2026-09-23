import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ai_job_identity.dart';
import '../models/audio_track.dart';
import '../models/lyric.dart';
import '../utils/local_file_url.dart';
import 'ai_audio_chunk_service.dart';
import 'ai_transcription_service.dart';
import 'asr_subtitle_cache.dart';
import 'cache_service.dart';
import 'kikoflu_feature_settings.dart';
import 'online_asr_service.dart';
import 'storage_service.dart';
import 'subtitle_language_settings.dart';

class AsrLocalModelNotInstalledException implements Exception {
  final String modelName;

  const AsrLocalModelNotInstalledException(this.modelName);

  @override
  String toString() => 'Local Whisper model $modelName is not installed.';
}

class AsrSubtitleFallbackResult {
  final List<LyricLine> lyrics;
  final bool fromCache;
  final String serviceName;
  final String sourceLanguage;

  const AsrSubtitleFallbackResult({
    required this.lyrics,
    required this.fromCache,
    required this.serviceName,
    required this.sourceLanguage,
  });
}

typedef AsrFallbackStatusCallback = void Function(String status);
typedef AsrPartialLyricsCallback = Future<void> Function(
  List<LyricLine> lyrics,
  bool isComplete,
);

class AsrSubtitleFallbackService {
  AsrSubtitleFallbackService._();

  static final instance = AsrSubtitleFallbackService._();

  Future<AsrSubtitleFallbackResult?> generate({
    required AudioTrack track,
    AsrFallbackStatusCallback? onStatus,
    AsrPartialLyricsCallback? onPartialLyrics,
    bool Function()? isCancelled,
  }) async {
    final identity = TrackIdentity.fromTrack(track);
    final featureSettings = KikoFluFeatureSettings.instance;
    final languageSettings = SubtitleLanguageSettings.instance;
    final requestedLanguage = languageSettings.sourceLanguage;

    final localModelName = featureSettings.whisperModel;
    final localProfile =
        'local-whisper-v2:$localModelName:$requestedLanguage:word=${featureSettings.whisperSplitOnWord}';

    onStatus?.call('Memeriksa subtitle ASR tersimpan…');
    final latestCached = await AsrSubtitleCache.instance.loadLatestForTrack(
      track: identity,
      language: requestedLanguage,
    );
    if (latestCached != null) {
      return AsrSubtitleFallbackResult(
        lyrics: latestCached.lines,
        fromCache: true,
        serviceName: latestCached.modelName,
        sourceLanguage: requestedLanguage,
      );
    }

    var localModelMissing = false;
    if (featureSettings.aiTranscriptionEnabled) {
      onStatus?.call('Memeriksa subtitle Whisper lokal tersimpan…');
      final cached = await AsrSubtitleCache.instance.load(
        track: identity,
        modelName: localProfile,
        language: requestedLanguage,
      );
      if (cached != null) {
        return AsrSubtitleFallbackResult(
          lyrics: cached,
          fromCache: true,
          serviceName: 'local-whisper-$localModelName',
          sourceLanguage: requestedLanguage,
        );
      }

      if (isCancelled?.call() == true) return null;

      final transcription = AiTranscriptionService.instance;
      final modelConfig = modelConfigFor(localModelName);
      final installed =
          await transcription.isModelConfigInstalled(modelConfig);
      if (installed) {
        final prepared = await _prepareAudioInput(
          track,
          onStatus: onStatus,
          isCancelled: isCancelled,
        );
        if (prepared != null) {
          try {
            final lyrics = await _transcribeLocalAudio(
              audioPath: prepared.path,
              totalDuration: track.segmentDuration ?? track.duration,
              transcription: transcription,
              modelName: localModelName,
              modelConfig: modelConfig,
              threads: featureSettings.whisperThreads,
              splitOnWord: featureSettings.whisperSplitOnWord,
              speedUp: featureSettings.whisperSpeedUp,
              language: requestedLanguage,
              onStatus: onStatus,
              onPartialLyrics: onPartialLyrics,
              isCancelled: isCancelled,
            );

            if (isCancelled?.call() == true) return null;
            if (lyrics.isNotEmpty) {
              await AsrSubtitleCache.instance.save(
                track: identity,
                modelName: localProfile,
                language: requestedLanguage,
                lines: lyrics,
              );
              return AsrSubtitleFallbackResult(
                lyrics: List.unmodifiable(lyrics),
                fromCache: false,
                serviceName: 'local-whisper-$localModelName',
                sourceLanguage: requestedLanguage,
              );
            }
          } catch (_) {
            // Online ASR remains an optional fallback when configured.
          } finally {
            await prepared.cleanup();
          }
        }
      } else {
        localModelMissing = true;
      }
    }

    if (isCancelled?.call() == true) return null;

    final endpoint = featureSettings.onlineAsrEndpoint.trim();
    if (endpoint.isEmpty) {
      if (featureSettings.aiTranscriptionEnabled && localModelMissing) {
        throw AsrLocalModelNotInstalledException(localModelName);
      }
      throw const OnlineAsrNotConfiguredException();
    }

    final selectedEngine = languageSettings.asrEngine;
    final onlineProfile = OnlineAsrService.cacheProfileFor(
      sourceLanguage: requestedLanguage,
      engine: selectedEngine,
    );

    onStatus?.call('Memeriksa subtitle ASR online tersimpan…');
    final onlineCached = await AsrSubtitleCache.instance.load(
      track: identity,
      modelName: onlineProfile,
      language: requestedLanguage,
    );
    if (onlineCached != null) {
      return AsrSubtitleFallbackResult(
        lyrics: onlineCached,
        fromCache: true,
        serviceName: 'online-cache',
        sourceLanguage: requestedLanguage,
      );
    }

    onStatus?.call('Membuat subtitle melalui ASR online…');
    _PreparedAsrAudio? onlinePrepared;
    var onlineTrack = track;
    if (_requiresSegmentExtraction(track)) {
      onlinePrepared = await _prepareAudioInput(
        track,
        onStatus: onStatus,
        isCancelled: isCancelled,
      );
      if (onlinePrepared == null) {
        throw const OnlineAsrInvalidResponseException(
          'Failed to isolate the active chapter for online ASR.',
        );
      }
      onlineTrack = track.copyWith(
        sourcePath: onlinePrepared.path,
        duration: track.segmentDuration ?? track.duration,
      );
    }

    final OnlineAsrResult result;
    try {
      result = await OnlineAsrService.instance.transcribe(
        onlineTrack,
        isCancelled: isCancelled,
      );
    } finally {
      await onlinePrepared?.cleanup();
    }
    if (isCancelled?.call() == true) return null;

    final lyrics = result.segments
        .where((segment) => segment.text.trim().isNotEmpty)
        .map(
          (segment) => LyricLine(
            startTime: Duration(
              milliseconds: (segment.startSeconds * 1000).round(),
            ),
            endTime: Duration(
              milliseconds: (segment.endSeconds * 1000).round(),
            ),
            text: segment.text.trim(),
          ),
        )
        .toList(growable: false);

    if (lyrics.isEmpty) return null;

    await AsrSubtitleCache.instance.save(
      track: identity,
      modelName: onlineProfile,
      language: requestedLanguage,
      lines: lyrics,
    );

    return AsrSubtitleFallbackResult(
      lyrics: List.unmodifiable(lyrics),
      fromCache: false,
      serviceName: result.serviceName,
      sourceLanguage: result.sourceLanguage,
    );
  }

  Future<List<LyricLine>> _transcribeLocalAudio({
    required String audioPath,
    required Duration? totalDuration,
    required AiTranscriptionService transcription,
    required String modelName,
    required LocalAiModelConfig modelConfig,
    required int threads,
    required bool splitOnWord,
    required bool speedUp,
    required String language,
    AsrFallbackStatusCallback? onStatus,
    AsrPartialLyricsCallback? onPartialLyrics,
    bool Function()? isCancelled,
  }) async {
    const firstChunkDuration = Duration(seconds: 10);
    const laterChunkDuration = Duration(seconds: 20);
    const chunkThreshold = Duration(seconds: 20);

    if (totalDuration == null || totalDuration <= chunkThreshold) {
      onStatus?.call(
        'Membuat subtitle dengan Whisper lokal ($modelName)…',
      );
      final result = await transcription.transcribeConfigured(
        audioPath,
        config: modelConfig,
        threads: threads,
        splitOnWord: splitOnWord,
        speedUp: speedUp,
        language: language,
      );
      return _lyricsFromSegments(
        result?.segments ?? const <WhisperSegment>[],
      );
    }

    final cumulative = <LyricLine>[];
    var start = Duration.zero;

    while (start < totalDuration) {
      if (isCancelled?.call() == true) break;

      final remaining = totalDuration - start;
      final preferredDuration =
          start == Duration.zero ? firstChunkDuration : laterChunkDuration;
      final currentDuration =
          remaining < preferredDuration ? remaining : preferredDuration;
      final end = start + currentDuration;

      onStatus?.call(
        'Membuat subtitle cepat '
        '${_formatClock(start)}–${_formatClock(end)}…',
      );

      final chunk = await AiAudioChunkService.instance.extractWavChunk(
        inputPath: audioPath,
        start: start,
        duration: currentDuration,
      );
      if (chunk == null) {
        if (start == Duration.zero) {
          onStatus?.call(
            'Mode cepat gagal menyiapkan potongan audio; mencoba file penuh…',
          );
          final fallback = await transcription.transcribeConfigured(
            audioPath,
            config: modelConfig,
            threads: threads,
            splitOnWord: splitOnWord,
            speedUp: speedUp,
            language: language,
          );
          return _lyricsFromSegments(
            fallback?.segments ?? const <WhisperSegment>[],
          );
        }
        break;
      }

      try {
        final result = await transcription.transcribeConfigured(
          chunk.path,
          config: modelConfig,
          threads: threads,
          splitOnWord: splitOnWord,
          speedUp: speedUp,
          convert: false,
          language: language,
        );
        if (isCancelled?.call() == true) break;

        final offsetLines = _lyricsFromSegments(
          result?.segments ?? const <WhisperSegment>[],
          offset: start,
        );
        if (offsetLines.isNotEmpty) {
          cumulative.addAll(offsetLines);
          final isComplete = end >= totalDuration;
          if (onPartialLyrics != null) {
            await onPartialLyrics(
              List<LyricLine>.unmodifiable(cumulative),
              isComplete,
            );
          }
        }
      } finally {
        try {
          if (await chunk.exists()) await chunk.delete();
        } catch (_) {}
      }

      start = end;
    }

    return List<LyricLine>.unmodifiable(cumulative);
  }

  List<LyricLine> _lyricsFromSegments(
    List<WhisperSegment> segments, {
    Duration offset = Duration.zero,
  }) {
    return segments
        .where((segment) => segment.text.trim().isNotEmpty)
        .map(
          (segment) => LyricLine(
            startTime: offset +
                Duration(
                  milliseconds: (segment.startSeconds * 1000).round(),
                ),
            endTime: offset +
                Duration(
                  milliseconds: (segment.endSeconds * 1000).round(),
                ),
            text: segment.text.trim(),
          ),
        )
        .toList(growable: false);
  }

  String _formatClock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<_PreparedAsrAudio?> _prepareAudioInput(
    AudioTrack track, {
    AsrFallbackStatusCallback? onStatus,
    bool Function()? isCancelled,
  }) async {
    for (final candidate in <String?>[
      track.sourcePath,
      LocalFileUrl.pathFromUrl(track.url),
    ]) {
      if (candidate == null || candidate.isEmpty) continue;
      final file = File(candidate);
      if (await file.exists()) {
        return _prepareSegmentIfNeeded(
          track,
          _PreparedAsrAudio(path: file.path),
          onStatus: onStatus,
          isCancelled: isCancelled,
        );
      }
    }

    final hash = track.hash;
    if (hash != null && hash.isNotEmpty) {
      final cached = await CacheService.getCachedAudioFile(hash);
      if (cached != null && await File(cached).exists()) {
        return _prepareSegmentIfNeeded(
          track,
          _PreparedAsrAudio(path: cached),
          onStatus: onStatus,
          isCancelled: isCancelled,
        );
      }
    }

    final uri = Uri.tryParse(track.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    if (isCancelled?.call() == true) return null;

    final tempDir = await getTemporaryDirectory();
    final extension = _audioExtension(track);
    final safeFingerprint = _safeFileComponent(track.hash ?? track.id);
    final tempFile = File(
      p.join(
        tempDir.path,
        'hiraukan_local_asr_${safeFingerprint}_'
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 20),
        headers: <String, dynamic>{
          ...StorageService.serverCookieHeaders,
          ...track.playbackHeaders,
        },
      ),
    );
    final cancelToken = CancelToken();

    try {
      onStatus?.call('Menyiapkan audio sementara untuk Whisper lokal…');
      await dio.download(
        track.url,
        tempFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (isCancelled?.call() == true && !cancelToken.isCancelled) {
            cancelToken.cancel('Track changed during local ASR preparation');
            return;
          }
          if (total > 0) {
            final percent = (received * 100 / total).clamp(0, 100).round();
            onStatus?.call('Menyiapkan audio… $percent%');
          }
        },
      );
      if (isCancelled?.call() == true) {
        if (await tempFile.exists()) await tempFile.delete();
        return null;
      }
      return _prepareSegmentIfNeeded(
        track,
        _PreparedAsrAudio(
          path: tempFile.path,
          deleteAfterUse: true,
        ),
        onStatus: onStatus,
        isCancelled: isCancelled,
      );
    } on DioException catch (error) {
      if (await tempFile.exists()) await tempFile.delete();
      if (CancelToken.isCancel(error)) return null;
      rethrow;
    }
  }

  bool _requiresSegmentExtraction(AudioTrack track) {
    if (!track.isSegmented) return false;

    // ASMR Hentai exposes one physical media file per source track. Its
    // start=0/end=duration metadata is still useful to the unified player, but
    // there is no longer source audio to cut away before ASR.
    if (track.sourceKey == 'asmr_hentai_net' &&
        track.segmentStart == Duration.zero) {
      return false;
    }

    final segmentDuration = track.segmentDuration;
    return segmentDuration != null && segmentDuration > Duration.zero;
  }

  Future<_PreparedAsrAudio?> _prepareSegmentIfNeeded(
    AudioTrack track,
    _PreparedAsrAudio prepared, {
    AsrFallbackStatusCallback? onStatus,
    bool Function()? isCancelled,
  }) async {
    if (!_requiresSegmentExtraction(track)) return prepared;
    if (isCancelled?.call() == true) {
      await prepared.cleanup();
      return null;
    }

    final segmentDuration = track.segmentDuration;
    if (segmentDuration == null || segmentDuration <= Duration.zero) {
      await prepared.cleanup();
      return null;
    }

    onStatus?.call('Menyiapkan chapter aktif untuk ASR…');
    final chunk = await AiAudioChunkService.instance.extractWavChunk(
      inputPath: prepared.path,
      start: track.segmentStart,
      duration: segmentDuration,
    );
    await prepared.cleanup();

    if (isCancelled?.call() == true) {
      if (chunk != null && await chunk.exists()) {
        try {
          await chunk.delete();
        } catch (_) {}
      }
      return null;
    }
    if (chunk == null) return null;

    return _PreparedAsrAudio(
      path: chunk.path,
      deleteAfterUse: true,
    );
  }

  String _audioExtension(AudioTrack track) {
    final candidates = <String>[
      track.sourcePath ?? '',
      Uri.tryParse(track.url)?.path ?? '',
      track.title,
    ];
    for (final candidate in candidates) {
      final extension = p.extension(candidate).toLowerCase();
      if (AiTranscriptionService.supportedAudioExtensions.contains(extension)) {
        return extension;
      }
    }
    return '.audio';
  }

  String _safeFileComponent(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }
}

class _PreparedAsrAudio {
  final String path;
  final bool deleteAfterUse;

  const _PreparedAsrAudio({
    required this.path,
    this.deleteAfterUse = false,
  });

  Future<void> cleanup() async {
    if (!deleteAfterUse) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
