import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';
import 'ai_transcription_service.dart';
import 'speech_recognition_engine.dart';

/// Adapter around Hiraukan's existing Whisper implementation.
///
/// This keeps the current feature intact while exposing it through the new
/// modular ASR contract. Future ReazonSpeech/Kotoba engines can implement the
/// same interface without touching the player or subtitle model.
class WhisperCompatibilityEngine implements SpeechRecognitionEngine {
  const WhisperCompatibilityEngine();

  @override
  String get id => 'whisper_existing';

  @override
  String get version => 'compat-v1';

  @override
  SpeechRecognitionProfile get profile =>
      SpeechRecognitionProfile.compatibility;

  @override
  Future<bool> isModelInstalled(String modelName) {
    final model = AiTranscriptionService.instance.modelFromName(modelName);
    return AiTranscriptionService.instance.isModelInstalled(model);
  }

  @override
  Future<TimedSubtitle?> transcribe(SpeechRecognitionRequest request) async {
    final model =
        AiTranscriptionService.instance.modelFromName(request.modelName);
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
            '${request.trackIdentity.trackId}:whisper:${entry.key}:${(segment.startSeconds * 1000).round()}',
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
          '${request.trackIdentity.trackId}:whisper',
      origin: SubtitleOrigin.aiGenerated,
      sourceKey: request.trackIdentity.sourceKey,
      sourceWorkId: request.trackIdentity.sourceWorkId,
      trackId: request.trackIdentity.trackId,
      audioFingerprint: request.trackIdentity.audioFingerprint,
      language: request.sourceLanguage,
      generatedBy: id,
      modelId: request.modelName,
      modelVersion: version,
      segments: segments,
      isComplete: true,
    );
  }
}
