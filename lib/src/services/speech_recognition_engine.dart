import '../models/ai_job_identity.dart';
import '../models/subtitle/timed_subtitle.dart';

enum SpeechRecognitionProfile {
  auto,
  fast,
  highQuality,
  compatibility,
}

class SpeechRecognitionRequest {
  final String audioPath;
  final TrackIdentity trackIdentity;
  final String sourceLanguage;
  final String modelName;
  final int threads;

  const SpeechRecognitionRequest({
    required this.audioPath,
    required this.trackIdentity,
    this.sourceLanguage = 'ja',
    this.modelName = 'base',
    this.threads = 4,
  });
}

abstract interface class SpeechRecognitionEngine {
  String get id;
  String get version;
  SpeechRecognitionProfile get profile;

  Future<bool> isModelInstalled(String modelName);

  Future<TimedSubtitle?> transcribe(SpeechRecognitionRequest request);
}
