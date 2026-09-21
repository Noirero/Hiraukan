import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:kikoeru_flutter/src/services/asr_benchmark.dart';
import 'package:kikoeru_flutter/src/services/asr_benchmark_lab_service.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('benchmark manifest resolves audio paths relative to manifest folder',
      () async {
    final dir = await Directory.systemTemp.createTemp(
      'hiraukan-asr-benchmark-lab-',
    );
    addTearDown(() => dir.delete(recursive: true));

    final audio = File(p.join(dir.path, 'soft.wav'));
    await audio.writeAsBytes(const [0, 1, 2, 3]);

    final manifest = File(p.join(dir.path, 'manifest.json'));
    await manifest.writeAsString('''
{
  "cases": [
    {
      "id": "soft",
      "category": "softWhisper",
      "audioPath": "soft.wav",
      "referenceText": "おやすみ",
      "durationMs": 1000
    }
  ]
}
''');

    final cases = await const AsrBenchmarkRunner().loadManifest(manifest);

    expect(cases, hasLength(1));
    expect(cases.single.audioPath, p.normalize(audio.path));
  });

  test('benchmark lab adds no Reazon or sherpa runtime', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final service = File(
      'lib/src/services/asr_benchmark_lab_service.dart',
    ).readAsStringSync();

    expect(pubspec, contains('whisper_ggml_plus'));
    expect(pubspec, isNot(contains('sherpa_onnx')));
    expect(pubspec, isNot(contains('reazon')));
    expect(service, contains('WhisperCompatibilityEngine'));
    expect(service, contains('WhisperFastCandidateEngine'));
    expect(service, contains('WhisperHighQualityCandidateEngine'));
  });

  test('benchmark report cannot silently unlock experimental profiles', () {
    expect(SpeechRecognitionCoordinator.fastProfileApproved, isFalse);
    expect(
      SpeechRecognitionCoordinator.highQualityProfileApproved,
      isFalse,
    );

    final service = File(
      'lib/src/services/asr_benchmark_lab_service.dart',
    ).readAsStringSync();
    expect(service, isNot(contains('fastProfileApproved = true')));
    expect(service, isNot(contains('highQualityProfileApproved = true')));
  });

  test('benchmark report records Fast and High Quality gate states', () {
    AsrBenchmarkSummary summary(String engineId) => AsrBenchmarkSummary(
          engineId: engineId,
          engineVersion: 'test',
          measurements: const [
            AsrBenchmarkMeasurement(
              caseId: 'case',
              category: AsrBenchmarkCategory.cleanSpeech,
              engineId: 'engine',
              engineVersion: 'test',
              hypothesisText: '日本語',
              characterErrorRate: 0.1,
              latencyMs: 500,
              realTimeFactor: 0.5,
              rssBeforeBytes: 100,
              rssAfterBytes: 120,
            ),
          ],
        );

    final result = AsrBenchmarkLabResult(
      manifestPath: '/tmp/manifest.json',
      reportPath: '/tmp/report.json',
      compatibility: summary('compat'),
      fast: summary('fast'),
      highQuality: summary('hq'),
      fastGate: const AsrBenchmarkGateResult(
        state: AsrBenchmarkGateState.passed,
        reasons: [],
      ),
      highQualityGate: const AsrBenchmarkGateResult(
        state: AsrBenchmarkGateState.failed,
        reasons: ['quality gate'],
      ),
    );

    final json = result.toJson();

    expect((json['fastGate'] as Map)['state'], 'passed');
    expect((json['highQualityGate'] as Map)['state'], 'failed');
  });
}
