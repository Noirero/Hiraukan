import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_coordinator.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_compatibility_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_fast_candidate_engine.dart';

void main() {
  test('Fast candidate reuses existing Whisper runtime', () {
    const fast = WhisperFastCandidateEngine();
    const compatibility = WhisperCompatibilityEngine();

    expect(fast.id, 'whisper_tiny_fast_candidate');
    expect(WhisperFastCandidateEngine.modelName, 'tiny');
    expect(fast.profile, SpeechRecognitionProfile.fast);
    expect(compatibility.profile, SpeechRecognitionProfile.compatibility);

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('whisper_ggml_plus'));
    expect(pubspec, isNot(contains('sherpa_onnx')));
    expect(pubspec, isNot(contains('reazon')));
  });

  test('Fast cannot become user-facing before benchmark approval', () async {
    expect(SpeechRecognitionCoordinator.fastProfileApproved, isFalse);

    await expectLater(
      SpeechRecognitionCoordinator.instance.resolveEngine(
        SpeechRecognitionProfile.fast,
      ),
      throwsA(isA<SpeechRecognitionProfileUnavailableException>()),
    );
  });

  test('Auto stays on Compatibility until Fast is approved', () async {
    final engine = await SpeechRecognitionCoordinator.instance.resolveEngine(
      SpeechRecognitionProfile.auto,
    );

    expect(engine.id, 'whisper_existing');
    expect(engine.profile, SpeechRecognitionProfile.compatibility);
  });

  test('unknown future profile names default to Compatibility', () {
    expect(
      SpeechRecognitionCoordinator.instance.profileFromName('future-profile'),
      SpeechRecognitionProfile.compatibility,
    );
  });

  test('High Quality remains unavailable until separately benchmarked', () async {
    await expectLater(
      SpeechRecognitionCoordinator.instance.resolveEngine(
        SpeechRecognitionProfile.highQuality,
      ),
      throwsA(isA<SpeechRecognitionProfileUnavailableException>()),
    );
  });
}
