import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/models/subtitle/subtitle_segment.dart';
import 'package:kikoeru_flutter/src/models/subtitle/timed_subtitle.dart';
import 'package:kikoeru_flutter/src/subtitles/ai_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/cached_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/source_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_controller.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_identity.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_presentation.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_request.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_translation_cache.dart';
import 'package:kikoeru_flutter/src/subtitles/translation_provider.dart';

TimedSubtitle _subtitle({
  String source = 'asmr_one',
  String workId = 'RJ123456',
  String trackId = 'track-1',
  String language = 'ja',
  String text = 'こんにちは',
  String generatedBy = 'source',
}) =>
    TimedSubtitle(
      id: '$source:$workId:$trackId:$language',
      source: source,
      workId: workId,
      trackId: trackId,
      language: language,
      generatedBy: generatedBy,
      segments: [
        SubtitleSegment(
          start: Duration.zero,
          end: const Duration(seconds: 1),
          text: text,
        ),
      ],
    );

AudioTrack _track({
  String id = 'track-1',
  String source = 'asmr_one',
  String workId = 'RJ123456',
}) =>
    AudioTrack(
      id: id,
      title: '$id.mp3',
      url: 'https://cdn.example/$source/$id.mp3',
      sourceKind: source,
      sourceLocalWorkId: workId,
      canonicalWorkId: workId,
      sourceTrackId: id,
    );

class _SourceProvider implements SourceSubtitleProvider {
  final Future<TimedSubtitle?> Function(SubtitleRequest request) onLoad;
  int calls = 0;

  _SourceProvider(this.onLoad);

  @override
  Future<TimedSubtitle?> load(SubtitleRequest request) async {
    calls++;
    return onLoad(request);
  }
}

class _OriginalCache implements CachedSubtitleProvider {
  TimedSubtitle? value;
  int loadCalls = 0;
  int saveCalls = 0;

  _OriginalCache({this.value});

  @override
  Future<TimedSubtitle?> load(SubtitleRequest request) async {
    loadCalls++;
    return value;
  }

  @override
  Future<void> save(SubtitleRequest request, TimedSubtitle subtitle) async {
    saveCalls++;
    value = subtitle;
  }
}

class _AiProvider implements AiSubtitleProvider {
  final TimedSubtitle? value;
  int calls = 0;

  _AiProvider(this.value);

  @override
  Future<TimedSubtitle?> generate(SubtitleRequest request) async {
    calls++;
    return value;
  }
}

class _AsyncAiProvider implements AiSubtitleProvider {
  final Future<TimedSubtitle?> Function(SubtitleRequest request) onGenerate;
  int calls = 0;

  _AsyncAiProvider(this.onGenerate);

  @override
  Future<TimedSubtitle?> generate(SubtitleRequest request) async {
    calls++;
    return onGenerate(request);
  }
}

class _TranslationProvider implements TranslationProvider {
  final Future<TimedSubtitle> Function(
    TimedSubtitle subtitle,
    String targetLanguage,
  ) onTranslate;
  int calls = 0;
  final List<String> targets = <String>[];

  _TranslationProvider(this.onTranslate);

  @override
  Future<TimedSubtitle> translate(
    TimedSubtitle subtitle, {
    required String targetLanguage,
  }) async {
    calls++;
    targets.add(targetLanguage);
    return onTranslate(subtitle, targetLanguage);
  }
}

TimedSubtitle _translated(
  TimedSubtitle original,
  String targetLanguage,
  String text,
) =>
    original.copyWith(
      id: '${original.id}:$targetLanguage',
      language: targetLanguage,
      generatedBy: 'fake_translation',
      segments: [original.segments.first.copyWith(text: text)],
    );

class _MemoryTranslationCache implements SubtitleTranslationCache {
  final Map<String, TimedSubtitle> entries = <String, TimedSubtitle>{};
  final List<SubtitleTranslationCacheKey> loadedKeys =
      <SubtitleTranslationCacheKey>[];
  final List<SubtitleTranslationCacheKey> savedKeys =
      <SubtitleTranslationCacheKey>[];

  @override
  Future<TimedSubtitle?> load(SubtitleTranslationCacheKey key) async {
    loadedKeys.add(key);
    return entries[key.stableKey];
  }

  @override
  Future<void> save(
    SubtitleTranslationCacheKey key,
    TimedSubtitle translatedSubtitle,
  ) async {
    savedKeys.add(key);
    entries[key.stableKey] = translatedSubtitle;
  }
}

void main() {
  test('original subtitle is retained after Indonesian translation', () async {
    final original = _subtitle();
    final translation = _TranslationProvider(
      (subtitle, target) async => _translated(subtitle, target, 'halo'),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(SubtitleDisplayMode.translated);

    expect(controller.state.originalSubtitle, same(original));
    expect(controller.state.subtitle, same(original));
    expect(controller.state.translatedSubtitle?.language, 'id');
    expect(controller.state.translatedSubtitle?.segments.single.text, 'halo');
    expect(controller.state.translationStatus, SubtitleTranslationStatus.ready);
    expect(translation.targets, ['id']);
    controller.dispose();
  });

  test('translated presentation keeps original and translated text separately',
      () async {
    final original = _subtitle(text: 'おはよう');
    final translation = _TranslationProvider(
      (subtitle, target) async => _translated(subtitle, target, 'selamat pagi'),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(SubtitleDisplayMode.translated);

    final segment = controller.state.presentation.segments.single;
    expect(controller.state.presentation.mode, SubtitleDisplayMode.translated);
    expect(segment.originalText, 'おはよう');
    expect(segment.translatedText, 'selamat pagi');
    controller.dispose();
  });

  test('bilingual presentation exposes original plus Indonesian translation',
      () async {
    final original = _subtitle(text: 'ありがとう');
    final translation = _TranslationProvider(
      (subtitle, target) async => _translated(subtitle, target, 'terima kasih'),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(SubtitleDisplayMode.bilingual);

    final segment = controller.state.presentation.segments.single;
    expect(controller.state.presentation.mode, SubtitleDisplayMode.bilingual);
    expect(segment.originalText, 'ありがとう');
    expect(segment.translatedText, 'terima kasih');
    controller.dispose();
  });

  test('changing subtitle display mode never invokes AI/STT again', () async {
    final ai = _AiProvider(_subtitle(generatedBy: 'ai'));
    final translation = _TranslationProvider(
      (subtitle, target) async => _translated(subtitle, target, 'halo'),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => null),
      cachedProvider: _OriginalCache(),
      aiProvider: ai,
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    expect(ai.calls, 1);

    await controller.setDisplayMode(SubtitleDisplayMode.translated);
    await controller.setDisplayMode(SubtitleDisplayMode.bilingual);
    await controller.setDisplayMode(SubtitleDisplayMode.original);

    expect(ai.calls, 1);
    expect(translation.calls, 1);
    controller.dispose();
  });

  test('translation cache is reused without calling provider again', () async {
    final original = _subtitle();
    final cache = _MemoryTranslationCache();
    final firstProvider = _TranslationProvider(
      (subtitle, target) async => _translated(subtitle, target, 'halo'),
    );
    final first = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: firstProvider,
      translationCache: cache,
    );

    await first.resolve(SubtitleRequest.forTrack(_track()));
    await first.setDisplayMode(SubtitleDisplayMode.translated);
    expect(firstProvider.calls, 1);
    expect(cache.savedKeys, hasLength(1));
    first.dispose();

    final secondProvider = _TranslationProvider(
      (subtitle, target) async =>
          throw StateError('provider must not be called on cache hit'),
    );
    final second = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: secondProvider,
      translationCache: cache,
    );

    await second.resolve(SubtitleRequest.forTrack(_track()));
    await second.setDisplayMode(SubtitleDisplayMode.translated);

    expect(secondProvider.calls, 0);
    expect(second.state.translatedSubtitle?.segments.single.text, 'halo');
    second.dispose();
  });

  test('different target languages use distinct translation cache identities',
      () async {
    final original = _subtitle();
    final cache = _MemoryTranslationCache();
    final translation = _TranslationProvider(
      (subtitle, target) async => _translated(
        subtitle,
        target,
        target == 'id' ? 'halo' : 'hello',
      ),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: cache,
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(
      SubtitleDisplayMode.translated,
      targetLanguage: 'id',
    );
    await controller.setTranslationTarget('en');

    expect(translation.targets, ['id', 'en']);
    expect(cache.savedKeys, hasLength(2));
    expect(cache.savedKeys[0].stableKey, isNot(cache.savedKeys[1].stableKey));
    expect(cache.savedKeys[0].targetLanguage, 'id');
    expect(cache.savedKeys[1].targetLanguage, 'en');
    controller.dispose();
  });

  test('translation failure keeps original subtitle usable', () async {
    final original = _subtitle();
    final translation = _TranslationProvider(
      (_, __) async => throw StateError('all providers failed'),
    );
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    final resolved = await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(SubtitleDisplayMode.translated);

    expect(resolved, same(original));
    expect(controller.state.status, SubtitleResolutionStatus.ready);
    expect(controller.state.originalSubtitle, same(original));
    expect(controller.state.translatedSubtitle, isNull);
    expect(
      controller.state.translationStatus,
      SubtitleTranslationStatus.unavailable,
    );
    expect(controller.state.presentation.isVisible, isTrue);
    final indonesiaOption = controller.state.ccOptions.firstWhere(
      (item) => item.option == SubtitleCcOption.automaticIndonesian,
    );
    expect(indonesiaOption.statusText, 'Terjemahan tidak tersedia');
    controller.dispose();
  });

  test('translation failure cannot turn subtitle resolution into playback error',
      () async {
    var playbackStillRunning = true;
    final original = _subtitle();
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationProvider: _TranslationProvider(
        (_, __) async => throw StateError('translation unavailable'),
      ),
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(SubtitleDisplayMode.bilingual);

    expect(playbackStillRunning, isTrue);
    expect(controller.state.status, SubtitleResolutionStatus.ready);
    expect(controller.state.error, isNull);
    expect(controller.state.originalSubtitle, same(original));
    controller.dispose();
  });

  test('stale translation from previous track is rejected', () async {
    final firstCompleter = Completer<TimedSubtitle>();
    final secondCompleter = Completer<TimedSubtitle>();
    final source = _SourceProvider((request) async {
      final trackId = request.identity.trackId;
      return _subtitle(trackId: trackId, text: 'original-$trackId');
    });
    final translation = _TranslationProvider((subtitle, target) {
      if (subtitle.trackId == 'track-1') return firstCompleter.future;
      return secondCompleter.future;
    });
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: _OriginalCache(),
      translationProvider: translation,
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track(id: 'track-1')));
    final pendingFirst =
        controller.setDisplayMode(SubtitleDisplayMode.translated);
    await pumpEventQueue();

    await controller.resolve(SubtitleRequest.forTrack(_track(id: 'track-2')));
    await pumpEventQueue();

    firstCompleter.complete(
      _translated(_subtitle(trackId: 'track-1'), 'id', 'lama'),
    );
    await pendingFirst;
    await pumpEventQueue();

    expect(controller.state.originalSubtitle?.trackId, 'track-2');
    expect(controller.state.translatedSubtitle?.trackId, isNot('track-1'));

    secondCompleter.complete(
      _translated(_subtitle(trackId: 'track-2'), 'id', 'baru'),
    );
    await pumpEventQueue();

    expect(controller.state.translatedSubtitle?.trackId, 'track-2');
    expect(controller.state.translatedSubtitle?.segments.single.text, 'baru');
    controller.dispose();
  });

  test('translation cache identity cannot collide across sources', () {
    final subtitle = _subtitle();
    const firstIdentity = SubtitleIdentity(
      source: 'asmr_one',
      sourceWorkId: '123456',
      trackId: 'track-1',
    );
    const secondIdentity = SubtitleIdentity(
      source: 'hentai_asmr',
      sourceWorkId: '123456',
      trackId: 'track-1',
    );

    final first = SubtitleTranslationCacheKey.fromSubtitle(
      identity: firstIdentity,
      subtitle: subtitle,
      targetLanguage: 'id',
    );
    final second = SubtitleTranslationCacheKey.fromSubtitle(
      identity: secondIdentity,
      subtitle: subtitle.copyWith(source: 'hentai_asmr'),
      targetLanguage: 'id',
    );

    expect(first.source, 'asmr_one');
    expect(second.source, 'hentai_asmr');
    expect(first.stableKey, isNot(second.stableKey));
    expect(first.storageKey, isNot(second.storageKey));
  });
  test('source-original CC stays unavailable when subtitle comes from AI',
      () async {
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => null),
      cachedProvider: _OriginalCache(),
      aiProvider: _AiProvider(_subtitle(generatedBy: 'ai')),
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));

    expect(controller.state.resolvedFrom, SubtitleResolvedFrom.ai);
    final sourceOriginal = controller.state.ccOptions.firstWhere(
      (item) => item.option == SubtitleCcOption.sourceOriginal,
    );
    final automaticOriginal = controller.state.ccOptions.firstWhere(
      (item) => item.option == SubtitleCcOption.automaticOriginal,
    );
    expect(sourceOriginal.available, isFalse);
    expect(sourceOriginal.label, 'Subtitle Asli — Tidak tersedia');
    expect(automaticOriginal.available, isTrue);
    controller.dispose();
  });

  test('AI subtitle generation is exposed as nonblocking CC busy state',
      () async {
    final completer = Completer<TimedSubtitle?>();
    final ai = _AsyncAiProvider((_) => completer.future);
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => null),
      cachedProvider: _OriginalCache(),
      aiProvider: ai,
      translationCache: _MemoryTranslationCache(),
    );

    final pending = controller.resolve(SubtitleRequest.forTrack(_track()));
    await pumpEventQueue();

    expect(ai.calls, 1);
    expect(controller.state.status, SubtitleResolutionStatus.loading);
    final automaticOriginal = controller.state.ccOptions.firstWhere(
      (item) => item.option == SubtitleCcOption.automaticOriginal,
    );
    expect(automaticOriginal.available, isTrue);
    expect(automaticOriginal.busy, isTrue);
    expect(automaticOriginal.statusText, 'Membuat subtitle…');

    completer.complete(_subtitle(generatedBy: 'ai'));
    await pending;
    expect(controller.state.status, SubtitleResolutionStatus.ready);
    controller.dispose();
  });

  test('native Indonesian subtitle does not require a translation provider',
      () async {
    final original = _subtitle(language: 'id', text: 'halo');
    final controller = SubtitleController(
      sourceProvider: _SourceProvider((_) async => original),
      cachedProvider: _OriginalCache(),
      translationCache: _MemoryTranslationCache(),
    );

    await controller.resolve(SubtitleRequest.forTrack(_track()));
    await controller.setDisplayMode(
      SubtitleDisplayMode.translated,
      targetLanguage: 'id',
    );

    expect(controller.state.translationSupported, isFalse);
    expect(controller.state.translatedSubtitle, same(original));
    expect(controller.state.translationStatus, SubtitleTranslationStatus.ready);
    expect(controller.state.translationError, isNull);
    final indonesiaOption = controller.state.ccOptions.firstWhere(
      (item) => item.option == SubtitleCcOption.automaticIndonesian,
    );
    expect(indonesiaOption.available, isTrue);
    expect(indonesiaOption.selected, isTrue);
    controller.dispose();
  });

  test('translation cache falls back to subtitle source and work identity',
      () {
    final subtitle = _subtitle(
      source: 'asmr_one',
      workId: 'RJ654321',
      trackId: 'track-legacy',
    );
    const legacyIdentity = SubtitleIdentity(
      source: 'legacy',
      trackId: 'track-legacy',
    );

    final key = SubtitleTranslationCacheKey.fromSubtitle(
      identity: legacyIdentity,
      subtitle: subtitle,
      targetLanguage: 'id',
    );

    expect(key.source, 'asmr_one');
    expect(key.workId, 'RJ654321');
    expect(key.trackId, 'track-legacy');
    expect(key.sourceLanguage, 'ja');
    expect(key.targetLanguage, 'id');
  });

}
