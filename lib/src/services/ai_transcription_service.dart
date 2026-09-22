import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:whisper_ggml_plus_ffmpeg/whisper_ggml_plus_ffmpeg.dart';

import 'ai_heavy_job_queue.dart';
import 'log_service.dart';

final _log = LogService.instance;

class WhisperSegment {
  final double startSeconds;
  final double endSeconds;
  final String text;

  const WhisperSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
}

class TranscriptionResult {
  final String fullText;
  final List<WhisperSegment> segments;
  final String lrcContent;

  const TranscriptionResult({
    required this.fullText,
    required this.segments,
    required this.lrcContent,
  });
}

class TranscriptionSavedEvent {
  final String audioPath;
  final String lrcPath;

  const TranscriptionSavedEvent({
    required this.audioPath,
    required this.lrcPath,
  });
}


class LocalAiModelConfig {
  final String id;
  final WhisperModel model;
  final String displayName;
  final String fileName;
  final int approximateSizeBytes;
  final String minRam;
  final int speedRating;
  final int accuracyRating;
  final bool recommended;
  final bool quantized;
  final String? badge;

  const LocalAiModelConfig({
    required this.id,
    required this.model,
    required this.displayName,
    required this.fileName,
    required this.approximateSizeBytes,
    required this.minRam,
    required this.speedRating,
    required this.accuracyRating,
    this.recommended = false,
    this.quantized = false,
    this.badge,
  });

  String get sizeLabel {
    final mib = approximateSizeBytes / (1024 * 1024);
    if (mib >= 1024) return '~${(mib / 1024).toStringAsFixed(1)} GB';
    return '~${mib.toStringAsFixed(0)} MB';
  }

  Uri get downloadUri => Uri.parse(
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$fileName',
      );
}

const localAiModelConfigs = <LocalAiModelConfig>[
  LocalAiModelConfig(
    id: 'tiny',
    model: WhisperModel.tiny,
    displayName: 'Tiny',
    fileName: 'ggml-tiny.bin',
    approximateSizeBytes: 75 * 1024 * 1024,
    minRam: '1 GB',
    speedRating: 5,
    accuracyRating: 2,
    badge: 'Fastest',
  ),
  LocalAiModelConfig(
    id: 'base_q5_1',
    model: WhisperModel.base,
    displayName: 'Base Q5_1',
    fileName: 'ggml-base-q5_1.bin',
    approximateSizeBytes: 60 * 1024 * 1024,
    minRam: '1.5 GB',
    speedRating: 5,
    accuracyRating: 3,
    quantized: true,
    badge: 'Lite',
  ),
  LocalAiModelConfig(
    id: 'base_q8_0',
    model: WhisperModel.base,
    displayName: 'Base Q8_0',
    fileName: 'ggml-base-q8_0.bin',
    approximateSizeBytes: 82 * 1024 * 1024,
    minRam: '2 GB',
    speedRating: 4,
    accuracyRating: 3,
    quantized: true,
    badge: 'Lite HQ',
  ),
  LocalAiModelConfig(
    id: 'base',
    model: WhisperModel.base,
    displayName: 'Base',
    fileName: 'ggml-base.bin',
    approximateSizeBytes: 150 * 1024 * 1024,
    minRam: '2 GB',
    speedRating: 4,
    accuracyRating: 3,
    recommended: true,
    badge: 'Balanced',
  ),
  LocalAiModelConfig(
    id: 'small_q5_1',
    model: WhisperModel.small,
    displayName: 'Small Q5_1',
    fileName: 'ggml-small-q5_1.bin',
    approximateSizeBytes: 182 * 1024 * 1024,
    minRam: '3 GB',
    speedRating: 4,
    accuracyRating: 4,
    quantized: true,
    badge: 'High Quality Lite',
  ),
  LocalAiModelConfig(
    id: 'small',
    model: WhisperModel.small,
    displayName: 'Small',
    fileName: 'ggml-small.bin',
    approximateSizeBytes: 500 * 1024 * 1024,
    minRam: '4 GB',
    speedRating: 3,
    accuracyRating: 4,
    badge: 'High Quality',
  ),
  LocalAiModelConfig(
    id: 'large_v3_turbo_q5_0',
    model: WhisperModel.largeV3Turbo,
    displayName: 'Large V3 Turbo Q5_0',
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    approximateSizeBytes: 547 * 1024 * 1024,
    minRam: '4 GB',
    speedRating: 3,
    accuracyRating: 4,
    quantized: true,
    badge: 'Advanced Lite',
  ),
  LocalAiModelConfig(
    id: 'medium',
    model: WhisperModel.medium,
    displayName: 'Medium',
    fileName: 'ggml-medium.bin',
    approximateSizeBytes: 1536 * 1024 * 1024,
    minRam: '6 GB',
    speedRating: 2,
    accuracyRating: 4,
    badge: 'Advanced',
  ),
  LocalAiModelConfig(
    id: 'largeV3Turbo',
    model: WhisperModel.largeV3Turbo,
    displayName: 'Large V3 Turbo',
    fileName: 'ggml-large-v3-turbo.bin',
    approximateSizeBytes: 1600 * 1024 * 1024,
    minRam: '6 GB',
    speedRating: 3,
    accuracyRating: 4,
    badge: 'Advanced',
  ),
  LocalAiModelConfig(
    id: 'large',
    model: WhisperModel.large,
    displayName: 'Large V3',
    fileName: 'ggml-large-v3.bin',
    approximateSizeBytes: 3072 * 1024 * 1024,
    minRam: '8 GB',
    speedRating: 1,
    accuracyRating: 5,
    badge: 'Maximum',
  ),
];

LocalAiModelConfig modelConfigFor(String name) {
  return localAiModelConfigs.firstWhere(
    (config) =>
        config.id == name ||
        config.model.name == name ||
        config.model.modelName == name,
    orElse: () => localAiModelConfigs.firstWhere(
      (config) => config.id == 'base',
    ),
  );
}

/// On-device Whisper transcription ported from KikoFlu.
/// Models are not bundled into the APK; they are downloaded/imported only
/// after the user explicitly enables and uses transcription.
class AiTranscriptionService {
  AiTranscriptionService._() {
    WhisperFFmpegConverter.register();
  }

  static final instance = AiTranscriptionService._();

  final StreamController<TranscriptionSavedEvent> _savedController =
      StreamController<TranscriptionSavedEvent>.broadcast(sync: true);

  Stream<TranscriptionSavedEvent> get savedLyrics => _savedController.stream;

  WhisperController? _controller;
  WhisperController get _ctrl => _controller ??= WhisperController();

  static const supportedAudioExtensions = <String>{
    '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wma', '.m4b',
  };

  WhisperModel modelFromName(String value) => modelConfigFor(value).model;

  Future<String> modelPathForConfig(LocalAiModelConfig config) async {
    if (!config.quantized) {
      return _ctrl.getPath(config.model);
    }
    final basePath = await _ctrl.getPath(config.model);
    return p.join(p.dirname(basePath), config.fileName);
  }

  Future<bool> isModelConfigInstalled(LocalAiModelConfig config) async {
    try {
      return File(await modelPathForConfig(config)).exists();
    } catch (_) {
      return false;
    }
  }

  Future<int?> modelConfigSize(LocalAiModelConfig config) async {
    try {
      final file = File(await modelPathForConfig(config));
      return await file.exists() ? await file.length() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteModelConfig(LocalAiModelConfig config) async {
    final path = await modelPathForConfig(config);
    final file = File(path);
    if (await file.exists()) await file.delete();
    final partial = File('$path.downloading');
    if (await partial.exists()) await partial.delete();
  }

  Future<String> importModelConfigFromFile({
    required String sourceFilePath,
    required LocalAiModelConfig config,
  }) async {
    final source = File(sourceFilePath);
    if (!await source.exists()) {
      throw FileSystemException('Model file not found', sourceFilePath);
    }
    if (p.extension(sourceFilePath).toLowerCase() != '.bin') {
      throw const FormatException('Whisper model must be a .bin file');
    }

    final destination = await modelPathForConfig(config);
    final target = File(destination);
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    await source.copy(destination);
    return destination;
  }

  Future<String> downloadModelConfig(
    LocalAiModelConfig config, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final destination = await modelPathForConfig(config);
    final complete = File(destination);
    if (await complete.exists()) return destination;

    final partial = File('$destination.downloading');
    await partial.parent.create(recursive: true);
    var existing = await partial.exists() ? await partial.length() : 0;
    var wake = false;

    try {
      await WakelockPlus.enable();
      wake = true;
    } catch (_) {}

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      var request = await client.getUrl(config.downloadUri);
      if (existing > 0) request.headers.set('Range', 'bytes=$existing-');
      var response = await request.close();

      if (existing > 0 && response.statusCode == 200) {
        existing = 0;
        if (await partial.exists()) await partial.delete();
      } else if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Whisper download failed: ${response.statusCode}',
        );
      }

      final total = response.contentLength > 0
          ? existing + response.contentLength
          : 0;
      var received = existing;
      final sink = partial.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );

      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          await sink.close();
          if (await partial.exists()) await partial.delete();
          throw const TranscriptionCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();

      if (await complete.exists()) await complete.delete();
      await partial.rename(destination);
      return destination;
    } finally {
      client.close(force: true);
      if (wake) {
        try {
          await WakelockPlus.disable();
        } catch (_) {}
      }
    }
  }

  // Backward-compatible helpers for legacy screens/tests.
  Future<bool> isModelInstalled(WhisperModel model) =>
      isModelConfigInstalled(
        localAiModelConfigs.firstWhere(
          (config) => config.model == model && !config.quantized,
        ),
      );

  Future<String> modelPath(WhisperModel model) => _ctrl.getPath(model);

  Future<int?> modelSize(WhisperModel model) => modelConfigSize(
        localAiModelConfigs.firstWhere(
          (config) => config.model == model && !config.quantized,
        ),
      );

  Future<void> deleteModel(WhisperModel model) => deleteModelConfig(
        localAiModelConfigs.firstWhere(
          (config) => config.model == model && !config.quantized,
        ),
      );

  Future<String> importModelFromFile({
    required String sourceFilePath,
    required WhisperModel model,
  }) =>
      importModelConfigFromFile(
        sourceFilePath: sourceFilePath,
        config: localAiModelConfigs.firstWhere(
          (config) => config.model == model && !config.quantized,
        ),
      );

  Future<String> downloadModel(
    WhisperModel model, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) =>
      downloadModelConfig(
        localAiModelConfigs.firstWhere(
          (config) => config.model == model && !config.quantized,
        ),
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

  Future<TranscriptionResult?> transcribe(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
    int threads = 6,
    bool splitOnWord = false,
    bool speedUp = true,
    bool convert = true,
    String language = 'auto',
  }) async {
    final audio = File(audioPath);
    if (!await audio.exists()) return null;
    if (!await isModelInstalled(model)) {
      throw StateError('Whisper model ${model.name} is not installed');
    }

    try {
      await WakelockPlus.enable();
      final result = await AiHeavyJobQueue.instance.run(
        () => _ctrl.transcribe(
          model: model,
          audioPath: audioPath,
          lang: _normalizeWhisperLanguage(language),
          withTimestamps: true,
          splitOnWord: splitOnWord,
          threads: threads.clamp(1, 16).toInt(),
          speedUp: speedUp,
          convert: convert,
        ),
      );
      if (result == null || result.transcription.text.trim().isEmpty) return null;

      final segments = <WhisperSegment>[];
      for (final segment in result.transcription.segments ?? const []) {
        segments.add(WhisperSegment(
          startSeconds: segment.fromTs.inMilliseconds / 1000,
          endSeconds: segment.toTs.inMilliseconds / 1000,
          text: segment.text.trim(),
        ));
      }
      return TranscriptionResult(
        fullText: result.transcription.text,
        segments: segments,
        lrcContent: _toLrc(segments),
      );
    } catch (error) {
      _log.error('Whisper transcription failed: $error', tag: 'AI');
      rethrow;
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  Future<TranscriptionResult?> transcribeConfigured(
    String audioPath, {
    required LocalAiModelConfig config,
    int threads = 6,
    bool splitOnWord = false,
    bool speedUp = true,
    bool convert = true,
    String language = 'auto',
  }) async {
    if (!config.quantized) {
      return transcribe(
        audioPath,
        model: config.model,
        threads: threads,
        splitOnWord: splitOnWord,
        speedUp: speedUp,
        convert: convert,
        language: language,
      );
    }

    final audio = File(audioPath);
    if (!await audio.exists()) return null;
    if (!await isModelConfigInstalled(config)) {
      throw StateError('Whisper model ${config.id} is not installed');
    }

    File? convertedAudio;
    var finalAudioPath = audioPath;
    if (convert && !audioPath.toLowerCase().endsWith('.wav')) {
      convertedAudio = await _convertWholeAudioToWav(audioPath);
      if (convertedAudio == null) {
        throw StateError('Failed to convert audio for quantized Whisper');
      }
      finalAudioPath = convertedAudio.path;
    }

    try {
      await WakelockPlus.enable();
      final modelPath = await modelPathForConfig(config);
      final transcription = await AiHeavyJobQueue.instance.run(
        () => Whisper(model: config.model).transcribe(
          transcribeRequest: TranscribeRequest(
            audio: finalAudioPath,
            language: _normalizeWhisperLanguage(language),
            threads: threads.clamp(1, 16).toInt(),
            isNoTimestamps: false,
            splitOnWord: splitOnWord,
            isRealtime: true,
            speedUp: speedUp,
          ),
          modelPath: modelPath,
        ),
      );

      if (transcription.text.trim().isEmpty) return null;
      final segments = <WhisperSegment>[];
      for (final segment in transcription.segments ?? const []) {
        segments.add(
          WhisperSegment(
            startSeconds: segment.fromTs.inMilliseconds / 1000,
            endSeconds: segment.toTs.inMilliseconds / 1000,
            text: segment.text.trim(),
          ),
        );
      }
      return TranscriptionResult(
        fullText: transcription.text,
        segments: segments,
        lrcContent: _toLrc(segments),
      );
    } catch (error) {
      _log.error(
        'Quantized Whisper transcription failed (${config.id}): $error',
        tag: 'AI',
      );
      rethrow;
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      if (convertedAudio != null) {
        try {
          if (await convertedAudio.exists()) await convertedAudio.delete();
        } catch (_) {}
      }
    }
  }

  Future<File?> _convertWholeAudioToWav(String inputPath) async {
    final tempDir = await getTemporaryDirectory();
    final output = File(
      p.join(
        tempDir.path,
        'hiraukan_whisper_quantized_'
        '${DateTime.now().microsecondsSinceEpoch}.wav',
      ),
    );

    String quote(String value) =>
        '"${value.replaceAll('"', '\\"')}"';

    final command = [
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      quote(inputPath),
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      '-y',
      quote(output.path),
    ].join(' ');

    final completer = Completer<Session>();
    FFmpegKit.executeAsync(
      command,
      (session) {
        if (!completer.isCompleted) completer.complete(session);
      },
    );

    final session = await completer.future;
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code) ||
        !await output.exists() ||
        await output.length() <= 44) {
      try {
        if (await output.exists()) await output.delete();
      } catch (_) {}
      return null;
    }
    return output;
  }

  /// Transcribes a finished audio file in short WAV chunks so the caller can
  /// publish useful subtitle text before the whole track has finished.
  ///
  /// whisper_ggml_plus itself is file/batch based and does not stream partial
  /// tokens, so chunking is the fast-start bridge used by Hiraukan.
  Future<TranscriptionResult?> transcribeChunked(
    String audioPath, {
    required Duration totalDuration,
    WhisperModel model = WhisperModel.base,
    int threads = 6,
    bool splitOnWord = false,
    bool speedUp = true,
    String language = 'auto',
    Duration chunkDuration = const Duration(seconds: 20),
    bool Function()? isCancelled,
    void Function(
      TranscriptionResult partial,
      int completedChunks,
      int totalChunks,
    )? onPartial,
  }) async {
    if (totalDuration <= Duration.zero ||
        totalDuration <= chunkDuration) {
      return transcribe(
        audioPath,
        model: model,
        threads: threads,
        splitOnWord: splitOnWord,
        speedUp: speedUp,
        language: language,
      );
    }

    final totalChunks =
        (totalDuration.inMilliseconds / chunkDuration.inMilliseconds).ceil();
    final allSegments = <WhisperSegment>[];
    final allText = <String>[];
    final tempDir = await getTemporaryDirectory();
    final runId = DateTime.now().microsecondsSinceEpoch;

    for (var chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
      if (isCancelled?.call() == true) {
        throw const TranscriptionCancelledException();
      }

      final start = Duration(
        milliseconds: chunkIndex * chunkDuration.inMilliseconds,
      );
      final remaining = totalDuration - start;
      if (remaining <= Duration.zero) break;
      final length =
          remaining < chunkDuration ? remaining : chunkDuration;

      final chunkFile = File(
        p.join(
          tempDir.path,
          'hiraukan_whisper_chunk_${runId}_$chunkIndex.wav',
        ),
      );

      try {
        final extracted = await _extractWhisperChunk(
          inputPath: audioPath,
          outputPath: chunkFile.path,
          start: start,
          duration: length,
        );
        if (!extracted) {
          throw StateError('Failed to prepare Whisper audio chunk');
        }

        final chunkResult = await transcribe(
          chunkFile.path,
          model: model,
          threads: threads,
          splitOnWord: splitOnWord,
          speedUp: speedUp,
          convert: false,
          language: language,
        );
        if (chunkResult != null) {
          final offsetSeconds = start.inMilliseconds / 1000.0;
          for (final segment in chunkResult.segments) {
            if (segment.text.trim().isEmpty) continue;
            allSegments.add(
              WhisperSegment(
                startSeconds: segment.startSeconds + offsetSeconds,
                endSeconds: segment.endSeconds + offsetSeconds,
                text: segment.text.trim(),
              ),
            );
          }
          final text = chunkResult.fullText.trim();
          if (text.isNotEmpty) allText.add(text);
        }

        if (allSegments.isNotEmpty && onPartial != null) {
          onPartial(
            TranscriptionResult(
              fullText: allText.join(' ').trim(),
              segments: List<WhisperSegment>.unmodifiable(allSegments),
              lrcContent: _toLrc(allSegments),
            ),
            chunkIndex + 1,
            totalChunks,
          );
        }
      } finally {
        try {
          if (await chunkFile.exists()) await chunkFile.delete();
        } catch (_) {}
      }
    }

    if (allSegments.isEmpty && allText.isEmpty) return null;
    return TranscriptionResult(
      fullText: allText.join(' ').trim(),
      segments: List<WhisperSegment>.unmodifiable(allSegments),
      lrcContent: _toLrc(allSegments),
    );
  }

  Future<bool> _extractWhisperChunk({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration duration,
  }) async {
    String quote(String value) =>
        '"${value.replaceAll('"', '\\"')}"';

    final startSeconds =
        (start.inMilliseconds / 1000).toStringAsFixed(3);
    final durationSeconds =
        (duration.inMilliseconds / 1000).toStringAsFixed(3);
    final command = [
      '-hide_banner',
      '-loglevel',
      'error',
      '-ss',
      startSeconds,
      '-t',
      durationSeconds,
      '-i',
      quote(inputPath),
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      '-y',
      quote(outputPath),
    ].join(' ');

    final completer = Completer<Session>();
    FFmpegKit.executeAsync(
      command,
      (session) {
        if (!completer.isCompleted) completer.complete(session);
      },
    );

    final session = await completer.future;
    final code = await session.getReturnCode();
    final output = File(outputPath);
    return ReturnCode.isSuccess(code) &&
        await output.exists() &&
        await output.length() > 44;
  }

  Future<String?> transcribeAndSave(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
    int threads = 6,
    bool overwrite = false,
    bool splitOnWord = false,
    bool speedUp = true,
    bool convert = true,
    String language = 'auto',
  }) async {
    final extension = p.extension(audioPath).toLowerCase();
    if (!supportedAudioExtensions.contains(extension)) return null;
    final lrcPath = p.setExtension(audioPath, '.lrc');
    if (!overwrite && await File(lrcPath).exists()) return lrcPath;

    final result = await transcribe(
      audioPath,
      model: model,
      threads: threads,
      splitOnWord: splitOnWord,
      speedUp: speedUp,
      language: language,
    );
    if (result == null) return null;
    await File(lrcPath).writeAsString(result.lrcContent, encoding: utf8, flush: true);
    _savedController.add(
      TranscriptionSavedEvent(audioPath: audioPath, lrcPath: lrcPath),
    );
    return lrcPath;
  }

  /// Scans only audio files. Existing .lrc/subtitle files are intentionally
  /// ignored, matching the later KikoFlu batch-transcription fix.
  Future<List<String>> scanAudioFiles(Directory root) async {
    if (!await root.exists()) return const [];
    final files = <String>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (supportedAudioExtensions.contains(p.extension(entity.path).toLowerCase())) {
        files.add(entity.path);
      }
    }
    files.sort();
    return files;
  }

  Future<BatchTranscriptionResult> transcribeDirectory(
    Directory root, {
    WhisperModel model = WhisperModel.base,
    int threads = 6,
    bool skipExisting = true,
    bool splitOnWord = false,
    bool speedUp = true,
    String language = 'auto',
    bool Function()? isCancelled,
    void Function(int done, int total, String path)? onProgress,
  }) async {
    final files = await scanAudioFiles(root);
    var completed = 0;
    var skipped = 0;
    var failed = 0;

    for (final path in files) {
      if (isCancelled?.call() == true) break;
      final lrcPath = p.setExtension(path, '.lrc');
      if (skipExisting && await File(lrcPath).exists()) {
        skipped++;
        onProgress?.call(completed + skipped + failed, files.length, path);
        continue;
      }
      try {
        final saved = await transcribeAndSave(
          path,
          model: model,
          threads: threads,
          overwrite: !skipExisting,
          splitOnWord: splitOnWord,
          speedUp: speedUp,
          language: language,
        );
        if (saved == null) {
          failed++;
        } else {
          completed++;
        }
      } catch (_) {
        failed++;
      }
      onProgress?.call(completed + skipped + failed, files.length, path);
    }

    return BatchTranscriptionResult(
      total: files.length,
      completed: completed,
      skipped: skipped,
      failed: failed,
    );
  }

  String _normalizeWhisperLanguage(String value) {
    final language = value.trim().toLowerCase().replaceAll('_', '-');
    if (language.isEmpty || language == 'auto') return 'auto';
    if (language.startsWith('zh')) return 'zh';
    return language.split('-').first;
  }

  String _toLrc(List<WhisperSegment> segments) {
    final output = StringBuffer()
      ..writeln('[ti:AI-Generated Transcription]')
      ..writeln('[by:Hiraukan Whisper]')
      ..writeln();
    for (final segment in segments) {
      if (segment.text.isEmpty) continue;
      final milliseconds = (segment.startSeconds * 1000).round();
      final minutes = milliseconds ~/ 60000;
      final seconds = (milliseconds % 60000) ~/ 1000;
      final hundredths = (milliseconds % 1000) ~/ 10;
      output.writeln(
        '[${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}]${segment.text}',
      );
    }
    return output.toString();
  }
}

class BatchTranscriptionResult {
  final int total;
  final int completed;
  final int skipped;
  final int failed;

  const BatchTranscriptionResult({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.failed,
  });
}

class TranscriptionCancelledException implements Exception {
  const TranscriptionCancelledException();
}
