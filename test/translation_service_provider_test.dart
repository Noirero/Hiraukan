import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/subtitle/subtitle_segment.dart';
import 'package:kikoeru_flutter/src/models/subtitle/timed_subtitle.dart';
import 'package:kikoeru_flutter/src/subtitles/translation_service_provider.dart';

class _FakeTranslationClient implements TranslationTextClient {
  int calls = 0;
  String? sourceLanguage;
  String? targetLanguage;
  List<String>? texts;
  Object? error;

  @override
  Future<List<String>> translateBatch(
    List<String> texts, {
    String? sourceLanguage,
    required String targetLanguage,
  }) async {
    calls++;
    this.texts = List<String>.from(texts);
    this.sourceLanguage = sourceLanguage;
    this.targetLanguage = targetLanguage;
    if (error != null) throw error!;
    return texts.map((text) => 'id:$text').toList(growable: false);
  }
}

TimedSubtitle _subtitle() => const TimedSubtitle(
      id: 'source-subtitle',
      source: 'asmr_one',
      workId: 'RJ123456',
      trackId: 'track-1',
      language: 'ja',
      generatedBy: 'source',
      segments: [
        SubtitleSegment(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'こんにちは',
        ),
        SubtitleSegment(
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
          text: 'ありがとう',
        ),
      ],
    );

void main() {
  test('TranslationServiceProvider implements TranslationProvider abstraction',
      () async {
    final client = _FakeTranslationClient();
    final provider = TranslationServiceProvider(client: client);
    final original = _subtitle();

    final translated = await provider.translate(
      original,
      targetLanguage: 'id',
    );

    expect(client.calls, 1);
    expect(client.sourceLanguage, 'ja');
    expect(client.targetLanguage, 'id');
    expect(client.texts, ['こんにちは', 'ありがとう']);
    expect(translated.source, original.source);
    expect(translated.workId, original.workId);
    expect(translated.trackId, original.trackId);
    expect(translated.language, 'id');
    expect(translated.generatedBy, 'translation_service');
    expect(translated.segments.map((segment) => segment.text), [
      'id:こんにちは',
      'id:ありがとう',
    ]);
    expect(original.language, 'ja');
    expect(original.segments.first.text, 'こんにちは');
  });

  test('adapter propagates provider failure instead of replacing original text',
      () async {
    final client = _FakeTranslationClient()
      ..error = StateError('all translation providers failed');
    final provider = TranslationServiceProvider(client: client);

    expect(
      () => provider.translate(_subtitle(), targetLanguage: 'id'),
      throwsA(isA<StateError>()),
    );
  });

  test('adapter rejects translation batches with mismatched segment count',
      () async {
    final provider = TranslationServiceProvider(
      client: _WrongLengthClient(),
    );

    expect(
      () => provider.translate(_subtitle(), targetLanguage: 'id'),
      throwsA(isA<StateError>()),
    );
  });
}

class _WrongLengthClient implements TranslationTextClient {
  @override
  Future<List<String>> translateBatch(
    List<String> texts, {
    String? sourceLanguage,
    required String targetLanguage,
  }) async {
    return const <String>['only one'];
  }
}
