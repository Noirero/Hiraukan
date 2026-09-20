import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';
import 'ai_transcription_service.dart';
import 'speech_recognition_engine.dart';

/// Zero-extra-runtime High Quality candidate using Hiraukan's existing
/// Whisper runtime. The Small model remains an optional user download.
class WhisperHighQualityCandidateEngine implements SpeechRecognitionEngine {
  const WhisperHighQualityCandidateEngine();

  static const modelName = 'small';

  @override
  String get id => 'whisper_small_hq_candidate';

  @override
  String get version => 'candidate-v1';

  @override
  SpeechRecognitionProfile get profile => SpeechRecognitionProfile.highQuality;

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
            '${request.trackIdentity.trackId}:whisper-hq:${entry.key}:'
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
          '${request.trackIdentity.trackId}:whisper-hq-candidate',
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
