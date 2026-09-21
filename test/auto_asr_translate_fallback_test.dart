import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/lyric_provider.dart';
import 'package:kikoeru_flutter/src/services/asr_subtitle_cache.dart';
import 'package:kikoeru_flutter/src/services/online_asr_service.dart';

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

  test('automatic subtitle fallback identifies the online ASR cache', () {
    expect(AsrSubtitleCache.engineId, 'online_asr_gateway');
    expect(AsrSubtitleCache.engineVersion, 'gateway-v1');
    expect(OnlineAsrService.cacheProfile, 'ja-online-v1');
  });

  test('automatic fallback does not use or download a local ASR model', () {
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(fallback, isNot(contains('AiTranscriptionService')));
    expect(fallback, isNot(contains('downloadModel(')));
    expect(fallback, contains('OnlineAsrService.instance.transcribe'));
  });

  test('online ASR endpoint can be supplied by build or app configuration', () {
    final settings =
        File('lib/src/services/kikoflu_feature_settings.dart').readAsStringSync();

    expect(settings, contains('online_asr_endpoint'));
    expect(settings, contains('HIRAUAKAN_ONLINE_ASR_ENDPOINT'));
  });

  test('online ASR fallback is independent from legacy Whisper enablement', () {
    final settings =
        File('lib/src/services/kikoflu_feature_settings.dart').readAsStringSync();
    final provider =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();

    expect(
      settings,
      contains("auto_asr_translate_fallback') ?? true"),
    );
    final helperStart = provider.indexOf('Future<bool> _tryAutomaticAsrFallback');
    final helperEnd = provider.indexOf(
      '// 从字幕库查找匹配的字幕文件',
      helperStart,
    );
    final helper = provider.substring(helperStart, helperEnd);
    expect(helper, isNot(contains('aiTranscriptionEnabled')));
  });

  test('downloaded Indonesian subtitle is restored without translation network',
      () {
    final provider =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();
    final cache = File(
      'lib/src/services/subtitle_translation_cache.dart',
    ).readAsStringSync();

    expect(provider, contains('_restoreDownloadedTranslationForCurrentTrack'));
    expect(provider, contains('loadDownloadedForTrack'));
    expect(provider, contains('offlineDownload: true'));
    expect(cache, contains("decoded['offlineDownload'] != true"));
    expect(cache, contains("'trackId': track.trackId"));
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

  test('generated Japanese subtitle still enters free online translation', () {
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

  test('Free Online translation is persisted only on explicit offline download',
      () {
    final source =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();
    expect(source, contains('downloadCurrentTranslationForOffline'));
    expect(source, contains('offlineDownload: true'));
  });

  test('source subtitle failure can fall through to ASR as the last fallback',
      () {
    final source =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<void> loadLyricForTrack');
    final helperStart = source.indexOf('Future<bool> _tryAutomaticAsrFallback');
    final method = source.substring(methodStart, helperStart);

    expect(method, contains('getCachedTextContent'));
    expect(method, contains('_tryAutomaticAsrFallback'));
    expect(method, contains('Subtitle source HTTP'));
  });
}
