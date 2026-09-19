import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kikoeru_flutter/src/models/lyric.dart';
import 'package:kikoeru_flutter/src/services/local_subtitle_translation_service.dart';
import 'package:kikoeru_flutter/src/services/local_translation_engine.dart';
import 'package:kikoeru_flutter/src/services/subtitle_translation_planner.dart';
import 'package:kikoeru_flutter/src/services/translation_glossary_service.dart';

class _FakeTranslationEngine implements LocalTranslationEngine {
  _FakeTranslationEngine(this.handler);

  final Future<String> Function(String text) handler;
  final calls = <String>[];

  @override
  String get id => 'fake';

  @override
  String get version => '1';

  @override
  String get displayName => 'Fake';

  @override
  Future<LocalTranslationModelStatus> getModelStatus() async {
    return const LocalTranslationModelStatus(
      state: LocalModelState.ready,
      engineId: 'fake',
      engineVersion: '1',
      sourceModelInstalled: true,
      targetModelInstalled: true,
    );
  }

  @override
  Future<LocalTranslationModelStatus> downloadModels({
    bool wifiOnly = true,
  }) =>
      getModelStatus();

  @override
  Future<LocalTranslationModelStatus> deleteModels() async {
    return const LocalTranslationModelStatus(
      state: LocalModelState.notInstalled,
      engineId: 'fake',
      engineVersion: '1',
      sourceModelInstalled: false,
      targetModelInstalled: false,
    );
  }

  @override
  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  }) async {
    calls.add(text);
    return handler(text);
  }
}

List<LyricLine> _lines(int count) {
  return List.generate(
    count,
    (index) => LyricLine(
      startTime: Duration(seconds: index),
      endTime: Duration(seconds: index + 1),
      text: 'line-$index',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('context translation uses the mapped center line when shape is stable',
      () async {
    final engine = _FakeTranslationEngine((text) async {
      if (text.contains('\n')) {
        return 'sebelum\nsekarang\nsesudah';
      }
      return 'fallback';
    });
    final service = LocalSubtitleTranslationService(engine: engine);

    final result = await service.translateSegment(
      sourceLines: const ['前', '今', '後'],
      index: 1,
      glossary: const TranslationGlossarySnapshot(
        version: 1,
        entries: [],
      ),
    );

    expect(result, 'sekarang');
    expect(engine.calls, hasLength(1));
  });

  test('context translation falls back to strict 1:1 when shape changes',
      () async {
    final engine = _FakeTranslationEngine((text) async {
      return text.contains('\n') ? 'merged output' : 'fallback satu baris';
    });
    final service = LocalSubtitleTranslationService(engine: engine);

    final result = await service.translateSegment(
      sourceLines: const ['前', '今', '後'],
      index: 1,
      glossary: const TranslationGlossarySnapshot(
        version: 1,
        entries: [],
      ),
    );

    expect(result, 'fallback satu baris');
    expect(engine.calls, hasLength(2));
  });

  test('glossary replacement survives translation through protected tokens',
      () async {
    final engine = _FakeTranslationEngine((text) async => text);
    final service = LocalSubtitleTranslationService(engine: engine);

    final result = await service.translateSegment(
      sourceLines: const ['お兄ちゃん、好き'],
      index: 0,
      contextEnabled: false,
      glossary: const TranslationGlossarySnapshot(
        version: 2,
        entries: [
          TranslationGlossaryEntry(
            source: 'お兄ちゃん',
            target: 'Kakak',
          ),
        ],
      ),
    );

    expect(result, 'Kakak、好き');
    expect(result, isNot(contains('ZXQGLOSS')));
  });

  test('playback planner reprioritizes after seek', () {
    final lyrics = _lines(24);
    final pending = <int>{for (var i = 0; i < lyrics.length; i++) i};

    expect(
      SubtitleTranslationPlanner.pickNextIndex(
        pending: pending,
        lyrics: lyrics,
        playbackPosition: const Duration(seconds: 10),
      ),
      10,
    );

    pending.remove(10);
    expect(
      SubtitleTranslationPlanner.pickNextIndex(
        pending: pending,
        lyrics: lyrics,
        playbackPosition: const Duration(seconds: 10),
      ),
      11,
    );

    expect(
      SubtitleTranslationPlanner.pickNextIndex(
        pending: pending,
        lyrics: lyrics,
        playbackPosition: const Duration(seconds: 20),
      ),
      20,
    );
  });

  test('editing glossary increments version and deduplicates source terms',
      () async {
    SharedPreferences.setMockInitialValues({});

    final first = await TranslationGlossaryService.instance.replaceAll(
      const [
        TranslationGlossaryEntry(source: '先生', target: 'Sensei'),
        TranslationGlossaryEntry(source: '先生', target: 'Guru'),
        TranslationGlossaryEntry(source: '  ', target: 'ignored'),
      ],
    );
    expect(first.entries, hasLength(1));
    expect(first.entries.single.target, 'Sensei');

    final second = await TranslationGlossaryService.instance.replaceAll(
      const [
        TranslationGlossaryEntry(source: '先生', target: 'Guru'),
      ],
    );
    expect(second.version, greaterThan(first.version));
    expect(second.entries.single.target, 'Guru');
  });
}
