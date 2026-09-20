import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ai_job_identity.dart';
import '../models/audio_track.dart';
import '../models/lyric.dart';
import '../utils/local_file_url.dart';
import 'ai_transcription_service.dart';
import 'asr_subtitle_cache.dart';
import 'cache_service.dart';
import 'storage_service.dart';

class AsrModelNotInstalledException implements Exception {
  final String modelName;

  const AsrModelNotInstalledException(this.modelName);

  @override
  String toString() => 'Whisper model $modelName is not installed.';
}

class AsrSubtitleFallbackResult {
  final List<LyricLine> lyrics;
  final bool fromCache;
  final String modelName;

  const AsrSubtitleFallbackResult({
    required this.lyrics,
    required this.fromCache,
    required this.modelName,
  });
}

typedef AsrFallbackStatusCallback = void Function(String status);

class AsrSubtitleFallbackService {
  AsrSubtitleFallbackService._();

  static final instance = AsrSubtitleFallbackService._();

  Future<AsrSubtitleFallbackResult?> generate({
    required AudioTrack track,
    required String modelName,
    required int threads,
    AsrFallbackStatusCallback? onStatus,
    bool Function()? isCancelled,
  }) async {
    final identity = TrackIdentity.fromTrack(track);

    onStatus?.call('Memeriksa cache subtitle AI…');
    final cached = await AsrSubtitleCache.instance.load(
      track: identity,
      modelName: modelName,
    );
    if (cached != null) {
      return AsrSubtitleFallbackResult(
        lyrics: cached,
        fromCache: true,
        modelName: modelName,
      );
    }

    if (isCancelled?.call() == true) return null;

    final transcription = AiTranscriptionService.instance;
    final model = transcription.modelFromName(modelName);
    final installed = await transcription.isModelInstalled(model);
    if (!installed) {
      throw AsrModelNotInstalledException(modelName);
    }

    onStatus?.call('Menyiapkan audio untuk ASR…');
    final prepared = await _prepareAudioInput(
      track,
      onStatus: onStatus,
      isCancelled: isCancelled,
    );
    if (prepared == null || isCancelled?.call() == true) {
      await prepared?.cleanup();
      return null;
    }

    try {
      onStatus?.call('Membuat subtitle Jepang dengan Whisper…');
      final result = await transcription.transcribe(
        prepared.path,
        model: model,
        threads: threads,
        splitOnWord: true,
      );
      if (result == null || isCancelled?.call() == true) return null;

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
        modelName: modelName,
        lines: lyrics,
      );
      if (isCancelled?.call() == true) return null;

      return AsrSubtitleFallbackResult(
        lyrics: List.unmodifiable(lyrics),
        fromCache: false,
        modelName: modelName,
      );
    } finally {
      await prepared.cleanup();
    }
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
        return _PreparedAsrAudio(path: file.path);
      }
    }

    final hash = track.hash;
    if (hash != null && hash.isNotEmpty) {
      final cached = await CacheService.getCachedAudioFile(hash);
      if (cached != null && await File(cached).exists()) {
        return _PreparedAsrAudio(path: cached);
      }
    }

    final uri = Uri.tryParse(track.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    if (isCancelled?.call() == true) return null;

    final tempDir = await getTemporaryDirectory();
    final extension = _audioExtension(track);
    final safeFingerprint = _safeFileComponent(
      track.hash ?? track.id,
    );
    final tempFile = File(
      p.join(
        tempDir.path,
        'hiraukan_asr_${safeFingerprint}_'
        '${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );

    final dio = Dio();
    dio.options.headers.addAll(StorageService.serverCookieHeaders);
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.options.receiveTimeout = const Duration(minutes: 15);
    final cancelToken = CancelToken();

    try {
      onStatus?.call('Mengunduh audio sementara untuk ASR…');
      await dio.download(
        track.url,
        tempFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (isCancelled?.call() == true && !cancelToken.isCancelled) {
            cancelToken.cancel('Track changed during ASR preparation');
            return;
          }
          if (total > 0) {
            final percent = (received * 100 / total).clamp(0, 100).round();
            onStatus?.call('Menyiapkan audio untuk ASR… $percent%');
          }
        },
      );

      if (isCancelled?.call() == true) {
        if (await tempFile.exists()) await tempFile.delete();
        return null;
      }

      return _PreparedAsrAudio(
        path: tempFile.path,
        deleteAfterUse: true,
      );
    } on DioException catch (error) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (CancelToken.isCancel(error)) return null;
      rethrow;
    }
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
    if (normalized.length <= 80) return normalized;
    return normalized.substring(0, 80);
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
    final file = File(path);
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temporary cleanup must never fail subtitle generation.
    }
  }
}
