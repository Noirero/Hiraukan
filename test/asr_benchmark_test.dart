import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kikoeru_flutter/src/services/android_ai_telemetry_service.dart';
import 'package:kikoeru_flutter/src/services/asr_benchmark.dart';

void main() {
  test('Japanese CER ignores punctuation and whitespace', () {
    expect(
      AsrBenchmarkEvaluator.characterErrorRate(
        'お兄ちゃん、好き！',
        'お兄ちゃん 好き',
      ),
      0,
    );
  });

  test('Japanese CER reports substitutions against reference length', () {
    expect(
      AsrBenchmarkEvaluator.characterErrorRate('あいうえお', 'あいくえお'),
      closeTo(0.2, 0.00001),
    );
  });

  test('benchmark manifest covers the required ASMR stress categories', () async {
    final dir = await Directory.systemTemp.createTemp('hiraukan-asr-benchmark-');
    addTearDown(() => dir.delete(recursive: true));

    final manifest = File('${dir.path}/manifest.json');
    await manifest.writeAsString(
      '''
{
  "cases": [
    {"id":"clean","category":"cleanSpeech","audioPath":"/tmp/clean.wav","referenceText":"普通の声","durationMs":1000},
    {"id":"soft","category":"softWhisper","audioPath":"/tmp/a.wav","referenceText":"囁き","durationMs":1000},
    {"id":"close","category":"closeMic","audioPath":"/tmp/b.wav","referenceText":"近い声","durationMs":1000},
    {"id":"binaural","category":"binaural","audioPath":"/tmp/c.wav","referenceText":"左右","durationMs":1000},
    {"id":"breath","category":"breathHeavy","audioPath":"/tmp/d.wav","referenceText":"息","durationMs":1000},
    {"id":"silence","category":"longSilence","audioPath":"/tmp/e.wav","referenceText":"間","durationMs":1000},
    {"id":"informal","category":"informalJapanese","audioPath":"/tmp/f.wav","referenceText":"好きだよ","durationMs":1000},
    {"id":"multi","category":"multiCharacter","audioPath":"/tmp/g.wav","referenceText":"二人","durationMs":1000}
  ]
}
''',
    );

    final cases = await const AsrBenchmarkRunner().loadManifest(manifest);
    final categories = cases.map((item) => item.category).toSet();

    expect(categories, contains(AsrBenchmarkCategory.cleanSpeech));
    expect(categories, contains(AsrBenchmarkCategory.softWhisper));
    expect(categories, contains(AsrBenchmarkCategory.closeMic));
    expect(categories, contains(AsrBenchmarkCategory.binaural));
    expect(categories, contains(AsrBenchmarkCategory.breathHeavy));
    expect(categories, contains(AsrBenchmarkCategory.longSilence));
    expect(categories, contains(AsrBenchmarkCategory.informalJapanese));
    expect(categories, contains(AsrBenchmarkCategory.multiCharacter));
  });

  AsrBenchmarkMeasurement measurement({
    required String id,
    required AsrBenchmarkCategory category,
    required double cer,
    required double rtf,
    int rssAfterBytes = 220 * 1024 * 1024,
    int? thermalBefore = 1,
    int? thermalAfter = 2,
  }) {
    return AsrBenchmarkMeasurement(
      caseId: id,
      category: category,
      engineId: 'engine',
      engineVersion: '1',
      hypothesisText: '仮説',
      characterErrorRate: cer,
      latencyMs: (rtf * 1000).round(),
      realTimeFactor: rtf,
      rssBeforeBytes: 180 * 1024 * 1024,
      rssAfterBytes: rssAfterBytes,
      telemetryBefore: AndroidAiTelemetrySnapshot(
        thermalStatus: thermalBefore,
      ),
      telemetryAfter: AndroidAiTelemetrySnapshot(
        thermalStatus: thermalAfter,
      ),
    );
  }

  List<AsrBenchmarkMeasurement> corpus({
    required double cer,
    required double rtf,
    int rssAfterBytes = 220 * 1024 * 1024,
  }) {
    return [
      measurement(
        id: 'clean',
        category: AsrBenchmarkCategory.cleanSpeech,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'soft',
        category: AsrBenchmarkCategory.softWhisper,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'close',
        category: AsrBenchmarkCategory.closeMic,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'binaural',
        category: AsrBenchmarkCategory.binaural,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'breath',
        category: AsrBenchmarkCategory.breathHeavy,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'silence',
        category: AsrBenchmarkCategory.longSilence,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'informal',
        category: AsrBenchmarkCategory.informalJapanese,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
      measurement(
        id: 'multi',
        category: AsrBenchmarkCategory.multiCharacter,
        cer: cer,
        rtf: rtf,
        rssAfterBytes: rssAfterBytes,
      ),
    ];
  }

  test('Fast acceptance passes only when speed improves without quality loss',
      () {
    final compatibility = AsrBenchmarkSummary(
      engineId: 'whisper',
      engineVersion: 'compat',
      measurements: corpus(cer: 0.20, rtf: 0.90),
    );
    final fast = AsrBenchmarkSummary(
      engineId: 'reazon',
      engineVersion: 'fast',
      measurements: corpus(
        cer: 0.24,
        rtf: 0.65,
        rssAfterBytes: 260 * 1024 * 1024,
      ),
    );

    final result = AsrFastAcceptanceEvaluator.evaluate(
      candidate: fast,
      compatibility: compatibility,
    );

    expect(result.state, AsrBenchmarkGateState.passed);
    expect(result.reasons, isEmpty);
  });

  test('Fast acceptance fails slow or heavily regressed candidate', () {
    final compatibility = AsrBenchmarkSummary(
      engineId: 'whisper',
      engineVersion: 'compat',
      measurements: corpus(cer: 0.18, rtf: 0.80),
    );
    final fast = AsrBenchmarkSummary(
      engineId: 'reazon',
      engineVersion: 'fast',
      measurements: corpus(cer: 0.48, rtf: 1.10),
    );

    final result = AsrFastAcceptanceEvaluator.evaluate(
      candidate: fast,
      compatibility: compatibility,
    );

    expect(result.state, AsrBenchmarkGateState.failed);
    expect(result.reasons, isNotEmpty);
  });

  test('Fast acceptance is incomplete without the full ASMR corpus', () {
    final compatibilityMeasurements = corpus(cer: 0.18, rtf: 0.80);
    final fastMeasurements = corpus(cer: 0.20, rtf: 0.60)
      ..removeWhere(
        (item) => item.category == AsrBenchmarkCategory.binaural,
      );
    final compatibility = AsrBenchmarkSummary(
      engineId: 'whisper',
      engineVersion: 'compat',
      measurements: compatibilityMeasurements
          .where((item) => item.category != AsrBenchmarkCategory.binaural)
          .toList(),
    );
    final fast = AsrBenchmarkSummary(
      engineId: 'reazon',
      engineVersion: 'fast',
      measurements: fastMeasurements,
    );

    final result = AsrFastAcceptanceEvaluator.evaluate(
      candidate: fast,
      compatibility: compatibility,
    );

    expect(result.state, AsrBenchmarkGateState.incomplete);
    expect(result.reasons.single, contains('binaural'));
  });

  test('Android telemetry snapshot tolerates partial device metrics', () {
    final snapshot = AndroidAiTelemetrySnapshot.fromMap({
      'sdkInt': 35,
      'thermalStatus': 2,
      'batteryPercent': 78.5,
      'batteryTemperatureTenthsC': 341,
    });

    expect(snapshot.sdkInt, 35);
    expect(snapshot.thermalStatus, 2);
    expect(snapshot.batteryPercent, 78.5);
    expect(snapshot.batteryTemperatureTenthsC, 341);
    expect(snapshot.batteryEnergyCounterNanoWh, isNull);
  });

  test('invalid benchmark category fails closed', () {
    expect(
      () => AsrBenchmarkCase.fromJson({
        'id': 'bad',
        'category': 'not-real',
        'audioPath': '/tmp/a.wav',
        'referenceText': 'text',
        'durationMs': 1000,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
