import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

    expect(categories, contains(AsrBenchmarkCategory.softWhisper));
    expect(categories, contains(AsrBenchmarkCategory.closeMic));
    expect(categories, contains(AsrBenchmarkCategory.binaural));
    expect(categories, contains(AsrBenchmarkCategory.breathHeavy));
    expect(categories, contains(AsrBenchmarkCategory.longSilence));
    expect(categories, contains(AsrBenchmarkCategory.informalJapanese));
    expect(categories, contains(AsrBenchmarkCategory.multiCharacter));
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
