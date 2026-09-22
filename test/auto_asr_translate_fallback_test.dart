import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/lyric_provider.dart';
import 'package:kikoeru_flutter/src/services/asr_subtitle_cache.dart';
import 'package:kikoeru_flutter/src/services/online_asr_service.dart';

void main() {
  test('ASR fallback state is independent from translation state', () {
    final state = LyricState(
      isGeneratingSubtitle: true,
      subtitleGenerationStatus: 'Membuat subtitle sumber…',
      subtitleGeneratedByAsr: true,
    );

    expect(state.isGeneratingSubtitle, isTrue);
    expect(state.isTranslating, isFalse);
    expect(state.subtitleGeneratedByAsr, isTrue);
  });

  test('ASR cache supports local and online engines', () {
    expect(AsrSubtitleCache.engineId, 'hiraukan_asr');
    expect(AsrSubtitleCache.engineVersion, 'local-online-v2');
    expect(
      OnlineAsrService.cacheProfileFor(sourceLanguage: 'ko', engine: 'auto'),
      'online-v2:auto:ko',
    );
  });

  test('automatic fallback prefers installed local Whisper without auto-download',
      () {
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(fallback, contains('AiTranscriptionService.instance'));
    expect(fallback, contains('isModelInstalled'));
    expect(fallback, isNot(contains('downloadModel(')));
    expect(fallback, contains('_transcribeLocalAudio('));
    expect(fallback, contains('AiAudioChunkService.instance.extractWavChunk'));
    expect(fallback, contains('OnlineAsrService.instance.transcribe'));

    final generateStart = fallback.indexOf(
      'Future<AsrSubtitleFallbackResult?> generate',
    );
    final localDispatch = fallback.indexOf(
      '_transcribeLocalAudio(',
      generateStart,
    );
    final onlineDispatch = fallback.indexOf(
      'OnlineAsrService.instance.transcribe',
      generateStart,
    );
    expect(localDispatch, greaterThanOrEqualTo(0));
    expect(onlineDispatch, greaterThan(localDispatch));
  });

  test('online ASR endpoint can be supplied by build or app configuration', () {
    final settings =
        File('lib/src/services/kikoflu_feature_settings.dart').readAsStringSync();

    expect(settings, contains('online_asr_endpoint'));
    expect(settings, contains('HIRAUAKAN_ONLINE_ASR_ENDPOINT'));
  });

  test('local Whisper remains opt-in and online ASR remains optional fallback',
      () {
    final settings =
        File('lib/src/services/kikoflu_feature_settings.dart').readAsStringSync();
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(settings, contains("ai_transcription') ?? false"));
    expect(
      settings,
      contains("auto_asr_translate_fallback') ?? true"),
    );
    expect(fallback, contains('featureSettings.aiTranscriptionEnabled'));
    expect(fallback, contains('featureSettings.onlineAsrEndpoint.trim()'));
  });

  test('downloaded target subtitle is restored without translation network',
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

  test('generated ASR subtitle survives model removal through cache discovery',
      () {
    final cache =
        File('lib/src/services/asr_subtitle_cache.dart').readAsStringSync();
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(cache, contains('loadLatestForTrack'));
    expect(fallback, contains('loadLatestForTrack'));
    expect(
      fallback.indexOf('loadLatestForTrack'),
      lessThan(fallback.indexOf('featureSettings.aiTranscriptionEnabled')),
    );
  });

  test('beta release does not require an online ASR server', () {
    final workflow = File('.github/workflows/build.yml').readAsStringSync();

    final inputStart = workflow.indexOf('asr_endpoint:');
    final inputEnd = workflow.indexOf('permissions:', inputStart);
    final inputBlock = workflow.substring(inputStart, inputEnd);
    expect(inputBlock, contains('required: false'));
    expect(
      workflow,
      contains('inputs.asr_endpoint || vars.HIRAUAKAN_ONLINE_ASR_ENDPOINT'),
    );
  });

  test('automatic ASR pauses playback until first translation is ready',
      () {
    final source =
        File('lib/src/providers/lyric_provider.dart').readAsStringSync();

    final helperStart =
        source.indexOf('Future<bool> _tryAutomaticAsrFallback');
    final helperEnd = source.indexOf(
      '// 从字幕库查找匹配的字幕文件',
      helperStart,
    );
    final helper = source.substring(helperStart, helperEnd);

    expect(helper, contains('final wasPlaying = ref.read(isPlayingProvider)'));
    expect(helper, contains('audioPlayerControllerProvider.notifier).pause()'));
    expect(helper, contains('_resumePlaybackWhenFirstTranslationIsReady'));
    expect(source, contains('state.translatedCount > 0'));
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

  test('generated source subtitle still enters free online translation', () {
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


