import 'speech_recognition_engine.dart';
import 'whisper_compatibility_engine.dart';
import 'whisper_fast_candidate_engine.dart';

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

  // Fast remains benchmark-only until real Android/ASMR measurements pass
  // AsrFastAcceptanceEvaluator. Keeping this false prevents compile-success
  // from silently promoting an experimental model to user-facing routing.
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
        return const WhisperFastCandidateEngine();
      case SpeechRecognitionProfile.highQuality:
        throw const SpeechRecognitionProfileUnavailableException(
          SpeechRecognitionProfile.highQuality,
          'High Quality ASR belum diaktifkan sampai engine HQ lolos benchmark.',
        );
      case SpeechRecognitionProfile.auto:
        if (!fastProfileApproved) {
          return const WhisperCompatibilityEngine();
        }
        final fast = const WhisperFastCandidateEngine();
        if (await fast.isModelInstalled(WhisperFastCandidateEngine.modelName)) {
          return fast;
        }
        return const WhisperCompatibilityEngine();
    }
  }
}
