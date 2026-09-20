import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/lyric_provider.dart';
import 'package:kikoeru_flutter/src/services/asr_subtitle_cache.dart';
import 'package:kikoeru_flutter/src/services/asr_subtitle_fallback_service.dart';

void main() {
  test('ASR fallback state is independent from translation state', () {
    final state = LyricState(
      isGeneratingSubtitle: true,
      subtitleGenerationStatus: 'Membuat subtitle Jepang…',
      subtitleGeneratedByAsr: true,
    );

    expect(state.isGeneratingSubtitle, isTrue);
    expect(state.isTranslating, isFalse);
    expect(state.subtitleGeneratedByAsr, isTrue);
  });

  test('ASR cache identity stays separate from translation cache', () {
    expect(AsrSubtitleCache.engineId, 'whisper_existing');
    expect(AsrSubtitleCache.engineVersion, 'compat-v1');
  });

  test('missing Whisper model is an explicit non-playback failure', () {
    const error = AsrModelNotInstalledException('base');
    expect(error.modelName, 'base');
    expect(error.toString(), contains('base'));
  });

  test('automatic fallback remains opt-in and never downloads a model silently',
      () {
    final settings =
        File('lib/src/services/kikoflu_feature_settings.dart').readAsStringSync();
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(
      settings,
      contains("auto_asr_translate_fallback') ?? false"),
    );
    expect(fallback, isNot(contains('downloadModel(')));
  });

  test('official/library subtitle lookup precedes ASR fallback', () {
    final source =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<void> loadLyricForTrack');
    final helperStart = source.indexOf('Future<bool> _tryAutomaticAsrFallback');
    expect(methodStart, greaterThanOrEqualTo(0));
    expect(helperStart, greaterThan(methodStart));

    final method = source.substring(methodStart, helperStart);
    final fileTreeLookup = method.indexOf('_findLyricFile(track, allFiles)');
    final libraryLookup = method.indexOf('_findLyricInLibrary(track)');
    final asrFallback = method.indexOf('_tryAutomaticAsrFallback');

    expect(fileTreeLookup, greaterThanOrEqualTo(0));
    expect(libraryLookup, greaterThanOrEqualTo(0));
    expect(asrFallback, greaterThan(fileTreeLookup));
    expect(asrFallback, greaterThan(libraryLookup));
  });

  test('generated Japanese subtitle automatically enters free online translation',
      () {
    final source =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();
    final helperStart = source.indexOf('Future<bool> _tryAutomaticAsrFallback');
    final helperEnd = source.indexOf(
      '// 从字幕库查找匹配的字幕文件',
      helperStart,
    );
    expect(helperStart, greaterThanOrEqualTo(0));
    expect(helperEnd, greaterThan(helperStart));

    final helper = source.substring(helperStart, helperEnd);
    expect(helper, contains('isFreeOnlineSelected()'));
    expect(helper, contains('translateAndSaveCurrentLyrics()'));
  });

  test('ASR fallback adds no Reazon or sherpa runtime to base APK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('sherpa_onnx')));
    expect(pubspec, contains('whisper_ggml_plus'));
  });
}
