import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';
import 'ai_transcription_service.dart';
import 'speech_recognition_engine.dart';

/// Zero-extra-runtime Fast candidate using Hiraukan's existing Whisper stack.
///
/// The tiny model is still downloaded separately. This candidate exists so the
/// benchmark can determine whether Reazon's additional native runtime is worth
/// its APK cost instead of assuming a second runtime is required for Fast ASR.
class WhisperFastCandidateEngine implements SpeechRecognitionEngine {
  const WhisperFastCandidateEngine();

  static const modelName = 'tiny';

  @override
  String get id => 'whisper_tiny_fast_candidate';

  @override
  String get version => 'candidate-v1';

  @override
  SpeechRecognitionProfile get profile => SpeechRecognitionProfile.fast;

  @override
  String get defaultModelName => modelName;

  @override
  Future<bool> isModelInstalled(String _) {
    final model = AiTranscriptionService.instance.modelFromName(modelName);
    return AiTranscriptionService.instance.isModelInstalled(model);
  }

  @override
  Future<TimedSubtitle?> transcribe(SpeechRecognitionRequest request) async {
    final model = AiTranscriptionService.instance.modelFromName(modelName);
    final result = await AiTranscriptionService.instance.transcribe(
      request.audioPath,
      model: model,
      threads: request.threads,
      splitOnWord: true,
    );
    if (result == null) return null;

    final segments = result.segments.asMap().entries.map((entry) {
      final segment = entry.value;
      return SubtitleSegment(
        id:
            '${request.trackIdentity.trackId}:whisper-fast:${entry.key}:'
            '${(segment.startSeconds * 1000).round()}',
        start: Duration(
          milliseconds: (segment.startSeconds * 1000).round(),
        ),
        end: Duration(
          milliseconds: (segment.endSeconds * 1000).round(),
        ),
        text: segment.text,
      );
    }).toList(growable: false);

    return TimedSubtitle(
      id:
          '${request.trackIdentity.sourceKey}:${request.trackIdentity.sourceWorkId}:'
          '${request.trackIdentity.trackId}:whisper-fast-candidate',
      origin: SubtitleOrigin.aiGenerated,
      sourceKey: request.trackIdentity.sourceKey,
      sourceWorkId: request.trackIdentity.sourceWorkId,
      trackId: request.trackIdentity.trackId,
      audioFingerprint: request.trackIdentity.audioFingerprint,
      language: request.sourceLanguage,
      generatedBy: id,
      modelId: modelName,
      modelVersion: version,
      segments: segments,
      isComplete: true,
    );
  }
}
