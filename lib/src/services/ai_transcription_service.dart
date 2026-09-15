import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';
import 'package:whisper_ggml_plus_ffmpeg/whisper_ggml_plus_ffmpeg.dart';

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

/// On-device Whisper transcription ported from KikoFlu.
/// Models are not bundled into the APK; they are downloaded/imported only
/// after the user explicitly enables and uses transcription.
class AiTranscriptionService {
  AiTranscriptionService._() {
    WhisperFFmpegConverter.register();
  }

  static final instance = AiTranscriptionService._();

  WhisperController? _controller;
  WhisperController get _ctrl => _controller ??= WhisperController();

  static const supportedAudioExtensions = <String>{
    '.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.opus', '.wma', '.m4b',
  };

  WhisperModel modelFromName(String value) => WhisperModel.values.firstWhere(
        (model) => model.name == value,
        orElse: () => WhisperModel.base,
      );

  Future<bool> isModelInstalled(WhisperModel model) async {
    try {
      return File(await _ctrl.getPath(model)).exists();
    } catch (_) {
      return false;
    }
  }

  Future<String> downloadModel(
    WhisperModel model, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final destination = await _ctrl.getPath(model);
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
      var request = await client.getUrl(model.modelUri);
      if (existing > 0) request.headers.set('Range', 'bytes=$existing-');
      var response = await request.close();

      if (existing > 0 && response.statusCode == 200) {
        existing = 0;
        if (await partial.exists()) await partial.delete();
      } else if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException('Whisper download failed: ${response.statusCode}');
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
        try { await WakelockPlus.disable(); } catch (_) {}
      }
    }
  }

  Future<TranscriptionResult?> transcribe(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
    int threads = 4,
    bool splitOnWord = false,
  }) async {
    final audio = File(audioPath);
    if (!await audio.exists()) return null;
    if (!await isModelInstalled(model)) {
      throw StateError('Whisper model ${model.name} is not installed');
    }

    try {
      await WakelockPlus.enable();
      final result = await _ctrl.transcribe(
        model: model,
        audioPath: audioPath,
        lang: 'ja',
        withTimestamps: true,
        splitOnWord: splitOnWord,
        threads: threads.clamp(1, 16),
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
      try { await WakelockPlus.disable(); } catch (_) {}
    }
  }

  Future<String?> transcribeAndSave(
    String audioPath, {
    WhisperModel model = WhisperModel.base,
    int threads = 4,
    bool overwrite = false,
  }) async {
    final extension = p.extension(audioPath).toLowerCase();
    if (!supportedAudioExtensions.contains(extension)) return null;
    final lrcPath = p.setExtension(audioPath, '.lrc');
    if (!overwrite && await File(lrcPath).exists()) return lrcPath;

    final result = await transcribe(
      audioPath,
      model: model,
      threads: threads,
      splitOnWord: true,
    );
    if (result == null) return null;
    await File(lrcPath).writeAsString(result.lrcContent, encoding: utf8);
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
    int threads = 4,
    bool skipExisting = true,
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
