import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/ai_job_identity.dart';
import '../models/subtitle/timed_subtitle.dart';
import 'ai_transcription_service.dart';
import 'reazon_fast_model_service.dart';
import 'reazon_speech_fast_engine.dart';
import 'speech_recognition_engine.dart';
import 'whisper_compatibility_engine.dart';

class SpeechRecognitionProfileUnavailableException implements Exception {
  final SpeechRecognitionProfile profile;
  final String message;

  const SpeechRecognitionProfileUnavailableException(
    this.profile,
    this.message,
  );

  @override
  String toString() => message;
}

class SpeechRecognitionCoordinator {
  SpeechRecognitionCoordinator._();

  static final SpeechRecognitionCoordinator instance =
      SpeechRecognitionCoordinator._();

  // Fast stays unavailable to normal profile routing until real Android/ASMR
  // benchmark results pass the acceptance policy in asr_benchmark.dart.
  static final bool fastProfileApproved = false;

  SpeechRecognitionProfile profileFromName(String value) {
    return SpeechRecognitionProfile.values.firstWhere(
      (profile) => profile.name == value,
      orElse: () => SpeechRecognitionProfile.compatibility,
    );
  }

  Future<SpeechRecognitionEngine> resolveEngine(
    SpeechRecognitionProfile profile,
  ) async {
    switch (profile) {
      case SpeechRecognitionProfile.compatibility:
        return const WhisperCompatibilityEngine();
      case SpeechRecognitionProfile.fast:
        if (!fastProfileApproved) {
          throw const SpeechRecognitionProfileUnavailableException(
            SpeechRecognitionProfile.fast,
            'Fast ASR masih eksperimental sampai benchmark Android/ASMR lulus.',
          );
        }
        return ReazonSpeechFastEngine.instance;
      case SpeechRecognitionProfile.highQuality:
        throw const SpeechRecognitionProfileUnavailableException(
          SpeechRecognitionProfile.highQuality,
          'High Quality ASR belum diaktifkan sampai engine HQ lolos benchmark.',
        );
      case SpeechRecognitionProfile.auto:
        if (!fastProfileApproved) {
          return const WhisperCompatibilityEngine();
        }
        final fast = await ReazonFastModelService.instance.status();
        if (fast.isReady) return ReazonSpeechFastEngine.instance;
        return const WhisperCompatibilityEngine();
    }
  }

  Future<String?> transcribeAndSave(
    String audioPath, {
    required SpeechRecognitionProfile profile,
    String whisperModel = 'base',
    int threads = 4,
    bool overwrite = false,
  }) async {
    final source = File(audioPath);
    if (!await source.exists()) return null;

    final extension = p.extension(audioPath).toLowerCase();
    if (!AiTranscriptionService.supportedAudioExtensions.contains(extension)) {
      return null;
    }

    final outputPath = p.setExtension(audioPath, '.lrc');
    final output = File(outputPath);
    if (!overwrite && await output.exists()) return outputPath;

    final engine = await resolveEngine(profile);
    final identity = await _identityForFile(source);
    final subtitle = await engine.transcribe(
      SpeechRecognitionRequest(
        audioPath: audioPath,
        trackIdentity: identity,
        sourceLanguage: 'ja',
        modelName: whisperModel,
        threads: threads,
      ),
    );
    if (subtitle == null || subtitle.segments.isEmpty) return null;

    final content = _toLrc(subtitle);
    final temporary = File('$outputPath.asr.tmp');
    try {
      await temporary.writeAsString(content, encoding: utf8, flush: true);
      if (await output.exists()) await output.delete();
      await temporary.rename(outputPath);
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }

    AiTranscriptionService.instance.notifySavedTranscription(
      audioPath: audioPath,
      lrcPath: outputPath,
    );
    return outputPath;
  }

  Future<BatchTranscriptionResult> transcribeDirectory(
    Directory root, {
    required SpeechRecognitionProfile profile,
    String whisperModel = 'base',
    int threads = 4,
    bool skipExisting = true,
    bool Function()? isCancelled,
    void Function(int done, int total, String path)? onProgress,
  }) async {
    final files = await AiTranscriptionService.instance.scanAudioFiles(root);
    var completed = 0;
    var skipped = 0;
    var failed = 0;

    for (final audioPath in files) {
      if (isCancelled?.call() == true) break;
      final lrcPath = p.setExtension(audioPath, '.lrc');

      if (skipExisting && await File(lrcPath).exists()) {
        skipped++;
        onProgress?.call(completed + skipped + failed, files.length, audioPath);
        continue;
      }

      try {
        final saved = await transcribeAndSave(
          audioPath,
          profile: profile,
          whisperModel: whisperModel,
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

      onProgress?.call(completed + skipped + failed, files.length, audioPath);
    }

    return BatchTranscriptionResult(
      total: files.length,
      completed: completed,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<TrackIdentity> _identityForFile(File file) async {
    final stat = await file.stat();
    final normalizedPath = p.normalize(file.absolute.path);
    final fingerprint = sha256
        .convert(
          utf8.encode(
            '$normalizedPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
          ),
        )
        .toString();

    return TrackIdentity(
      trackId: p.basenameWithoutExtension(file.path),
      sourceKey: 'local',
      sourceWorkId: p.basename(file.parent.path),
      audioFingerprint: fingerprint,
    );
  }

  String _toLrc(TimedSubtitle subtitle) {
    final output = StringBuffer()
      ..writeln('[ti:AI-Generated Transcription]')
      ..writeln('[by:Hiraukan ${subtitle.generatedBy ?? 'ASR'}]')
      ..writeln();

    for (final segment in subtitle.segments) {
      if (segment.text.trim().isEmpty) continue;
      final milliseconds = segment.start.inMilliseconds;
      final minutes = milliseconds ~/ 60000;
      final seconds = (milliseconds % 60000) ~/ 1000;
      final hundredths = (milliseconds % 1000) ~/ 10;
      output.writeln(
        '[${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}]${segment.text.trim()}',
      );
    }
    return output.toString();
  }
}
