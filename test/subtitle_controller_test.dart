import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/models/subtitle/subtitle_segment.dart';
import 'package:kikoeru_flutter/src/models/subtitle/timed_subtitle.dart';
import 'package:kikoeru_flutter/src/subtitles/ai_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/cached_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/source_subtitle_provider.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_controller.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_request.dart';

TimedSubtitle _subtitle(String generatedBy) => TimedSubtitle(
      id: generatedBy,
      source: 'asmr_one',
      workId: 'RJ123456',
      trackId: 'track-1',
      language: 'ja',
      generatedBy: generatedBy,
      segments: const [
        SubtitleSegment(
          start: Duration.zero,
          end: Duration(seconds: 1),
          text: 'hello',
        ),
      ],
    );

final _track = AudioTrack(
  id: 'track-1',
  title: '01.mp3',
  url: 'https://cdn.example/01.mp3',
  sourceKind: 'asmr_one',
  sourceLocalWorkId: '123456',
  canonicalWorkId: 'RJ123456',
  sourceTrackId: 'track-1',
);

class _SourceProvider implements SourceSubtitleProvider {
  TimedSubtitle? value;
  Object? error;
  int calls = 0;
  Completer<TimedSubtitle?>? completer;

  _SourceProvider({this.value, this.error, this.completer});

  @override
  Future<TimedSubtitle?> load(SubtitleRequest request) async {
    calls++;
    if (error != null) throw error!;
    if (completer != null) return completer!.future;
    return value;
  }
}

class _CacheProvider implements CachedSubtitleProvider {
  TimedSubtitle? value;
  Object? loadError;
  bool failSave;
  int loadCalls = 0;
  int saveCalls = 0;

  _CacheProvider({
    this.value,
    this.loadError,
    this.failSave = false,
  });

  @override
  Future<TimedSubtitle?> load(SubtitleRequest request) async {
    loadCalls++;
    if (loadError != null) throw loadError!;
    return value;
  }

  @override
  Future<void> save(SubtitleRequest request, TimedSubtitle subtitle) async {
    saveCalls++;
    if (failSave) throw StateError('cache write failed');
    value = subtitle;
  }
}

class _AiProvider implements AiSubtitleProvider {
  TimedSubtitle? value;
  Object? error;
  int calls = 0;

  _AiProvider({this.value, this.error});

  @override
  Future<TimedSubtitle?> generate(SubtitleRequest request) async {
    calls++;
    if (error != null) throw error!;
    return value;
  }
}

void main() {
  test('source subtitle has priority over cache and AI', () async {
    final source = _SourceProvider(value: _subtitle('source'));
    final cache = _CacheProvider(value: _subtitle('cache'));
    final ai = _AiProvider(value: _subtitle('ai'));
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: cache,
      aiProvider: ai,
    );

    final result = await controller.resolve(SubtitleRequest.forTrack(_track));

    expect(result?.generatedBy, 'source');
    expect(controller.state.resolvedFrom, SubtitleResolvedFrom.source);
    expect(source.calls, 1);
    expect(cache.loadCalls, 0);
    expect(ai.calls, 0);
    controller.dispose();
  });

  test('source failure is isolated and cached subtitle is reused', () async {
    final source = _SourceProvider(error: StateError('source unavailable'));
    final cache = _CacheProvider(value: _subtitle('cache'));
    final ai = _AiProvider(value: _subtitle('ai'));
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: cache,
      aiProvider: ai,
    );

    final result = await controller.resolve(SubtitleRequest.forTrack(_track));

    expect(result?.generatedBy, 'cache');
    expect(controller.state.status, SubtitleResolutionStatus.ready);
    expect(controller.state.resolvedFrom, SubtitleResolvedFrom.cache);
    expect(ai.calls, 0);
    controller.dispose();
  });

  test('AI result remains usable even when cache write fails', () async {
    final source = _SourceProvider();
    final cache = _CacheProvider(failSave: true);
    final ai = _AiProvider(value: _subtitle('ai'));
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: cache,
      aiProvider: ai,
    );

    final result = await controller.resolve(SubtitleRequest.forTrack(_track));

    expect(result?.generatedBy, 'ai');
    expect(cache.saveCalls, 1);
    expect(controller.state.status, SubtitleResolutionStatus.ready);
    expect(controller.state.resolvedFrom, SubtitleResolvedFrom.ai);
    controller.dispose();
  });

  test('AI can be disabled without affecting source/cache resolution', () async {
    final source = _SourceProvider();
    final cache = _CacheProvider();
    final ai = _AiProvider(value: _subtitle('ai'));
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: cache,
      aiProvider: ai,
    );

    final result = await controller.resolve(
      SubtitleRequest.forTrack(_track, allowAi: false),
    );

    expect(result, isNull);
    expect(ai.calls, 0);
    expect(controller.state.status, SubtitleResolutionStatus.unavailable);
    controller.dispose();
  });

  test('stale subtitle work is ignored after cancellation', () async {
    final completer = Completer<TimedSubtitle?>();
    final source = _SourceProvider(completer: completer);
    final cache = _CacheProvider();
    final controller = SubtitleController(
      sourceProvider: source,
      cachedProvider: cache,
    );

    final pending = controller.resolve(SubtitleRequest.forTrack(_track));
    controller.cancelCurrent();
    completer.complete(_subtitle('source'));

    expect(await pending, isNull);
    expect(controller.state.status, SubtitleResolutionStatus.idle);
    expect(cache.loadCalls, 0);
    controller.dispose();
  });
}
