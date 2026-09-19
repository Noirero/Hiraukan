import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';
import 'ai_heavy_job_queue.dart';
import 'audio_conversion_service.dart';
import 'reazon_fast_model_service.dart';
import 'speech_recognition_engine.dart';

class ReazonSpeechFastEngine implements SpeechRecognitionEngine {
  ReazonSpeechFastEngine._();

  static final ReazonSpeechFastEngine instance = ReazonSpeechFastEngine._();

  static Future<void>? _bindingsFuture;
  static const int _chunkSeconds = 20;

  @override
  String get id => 'reazonspeech_k2_v2';

  @override
  String get version => ReazonFastModelService.modelRevision;

  @override
  SpeechRecognitionProfile get profile => SpeechRecognitionProfile.fast;

  @override
  Future<bool> isModelInstalled(String modelName) async {
    return (await ReazonFastModelService.instance.status()).isReady;
  }

  @override
  Future<TimedSubtitle?> transcribe(SpeechRecognitionRequest request) async {
    if (request.sourceLanguage.toLowerCase() != 'ja') {
      throw UnsupportedError(
        'Reazon Fast currently supports Japanese speech only.',
      );
    }

    final modelStatus = await ReazonFastModelService.instance.status();
    if (!modelStatus.isReady) {
      throw StateError(
        modelStatus.message ?? 'Reazon Fast model is not installed.',
      );
    }

    final wavPath = await AudioConversionService.instance
        .prepareSpeechRecognitionWav(request.audioPath);
    if (wavPath == null) {
      throw StateError('Unable to prepare 16 kHz PCM audio for Fast ASR.');
    }

    try {
      return await AiHeavyJobQueue.instance.run(
        () => _transcribePreparedWav(request, wavPath),
      );
    } finally {
      final temporary = File(wavPath);
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }
  }

  Future<TimedSubtitle?> _transcribePreparedWav(
    SpeechRecognitionRequest request,
    String wavPath,
  ) async {
    await (_bindingsFuture ??= sherpa.initBindingsAsync());

    final modelPaths = await ReazonFastModelService.instance.paths();
    final transducer = sherpa.OfflineTransducerModelConfig(
      encoder: modelPaths.encoder,
      decoder: modelPaths.decoder,
      joiner: modelPaths.joiner,
    );
    final modelConfig = sherpa.OfflineModelConfig(
      transducer: transducer,
      tokens: modelPaths.tokens,
      debug: false,
      numThreads: request.threads.clamp(1, 4).toInt(),
    );
    final config = sherpa.OfflineRecognizerConfig(model: modelConfig);
    final recognizer = sherpa.OfflineRecognizer(config);

    try {
      final wave = sherpa.readWave(wavPath);
      if (wave.sampleRate != 16000) {
        throw StateError(
          'Fast ASR requires 16000 Hz input, got ${wave.sampleRate}.',
        );
      }

      final samplesPerChunk = wave.sampleRate * _chunkSeconds;
      final segments = <SubtitleSegment>[];

      for (var start = 0;
          start < wave.samples.length;
          start += samplesPerChunk) {
        final end = (start + samplesPerChunk < wave.samples.length)
            ? start + samplesPerChunk
            : wave.samples.length;
        if (end <= start) break;

        final samples = Float32List.sublistView(
          wave.samples,
          start,
          end,
        );
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(
            samples: samples,
            sampleRate: wave.sampleRate,
          );
          recognizer.decode(stream);
          final result = recognizer.getResult(stream);
          final text = result.text.trim();
          if (text.isEmpty) continue;

          final startMs = (start * 1000 / wave.sampleRate).round();
          final endMs = (end * 1000 / wave.sampleRate).round();
          segments.add(
            SubtitleSegment(
              id:
                  '${request.trackIdentity.trackId}:reazon:$startMs:$endMs',
              start: Duration(milliseconds: startMs),
              end: Duration(milliseconds: endMs),
              text: text,
            ),
          );
        } finally {
          stream.free();
        }
      }

      if (segments.isEmpty) return null;
      return TimedSubtitle(
        id:
            '${request.trackIdentity.sourceKey}:'
            '${request.trackIdentity.sourceWorkId}:'
            '${request.trackIdentity.trackId}:reazon-fast',
        origin: SubtitleOrigin.aiGenerated,
        sourceKey: request.trackIdentity.sourceKey,
        sourceWorkId: request.trackIdentity.sourceWorkId,
        trackId: request.trackIdentity.trackId,
        audioFingerprint: request.trackIdentity.audioFingerprint,
        language: 'ja',
        generatedBy: id,
        modelId: ReazonFastModelService.modelId,
        modelVersion: version,
        segments: segments,
        isComplete: true,
      );
    } finally {
      recognizer.free();
    }
  }
}
