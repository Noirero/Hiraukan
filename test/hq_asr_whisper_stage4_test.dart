import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_coordinator.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_high_quality_candidate_engine.dart';

void main() {
  test('High Quality candidate reuses existing Whisper runtime', () {
    const candidate = WhisperHighQualityCandidateEngine();

    expect(candidate.id, 'whisper_small_hq_candidate');
    expect(WhisperHighQualityCandidateEngine.modelName, 'small');
    expect(candidate.profile, SpeechRecognitionProfile.highQuality);

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('whisper_ggml_plus'));
    expect(pubspec, isNot(contains('sherpa_onnx')));
    expect(pubspec, isNot(contains('reazon')));
  });

  test('High Quality cannot become user-facing before benchmark approval',
      () async {
    expect(
      SpeechRecognitionCoordinator.highQualityProfileApproved,
      isFalse,
    );

    await expectLater(
      SpeechRecognitionCoordinator.instance.resolveEngine(
        SpeechRecognitionProfile.highQuality,
      ),
      throwsA(isA<SpeechRecognitionProfileUnavailableException>()),
    );
  });

  test('HQ model remains optional and is never bundled or silently downloaded',
      () {
    final engineSource = File(
      'lib/src/services/whisper_high_quality_candidate_engine.dart',
    ).readAsStringSync();

    expect(engineSource, contains("static const modelName = 'small'"));
    expect(engineSource, isNot(contains('downloadModel(')));
  });
}
