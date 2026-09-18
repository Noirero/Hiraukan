import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/models/lyric/lyric_line.dart';
import 'package:kikoeru_flutter/src/models/subtitle/timed_subtitle.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_controller.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_format_adapter.dart';

void main() {
  const track = AudioTrack(
    id: 'track-01',
    title: '01.mp3',
    url: 'https://cdn.example/01.mp3',
    workId: 123456,
    hash: 'audio-hash',
    sourceKey: 'asmr_one',
    sourceWorkId: 'RJ123456',
  );

  final lyrics = <LyricLine>[
    LyricLine(
      startTime: const Duration(seconds: 1),
      endTime: const Duration(seconds: 3),
      text: 'こんにちは',
    ),
    LyricLine(
      startTime: const Duration(seconds: 4),
      endTime: const Duration(seconds: 7),
      text: 'ゆっくり休んでください',
    ),
  ];

  test('legacy lyric bridge preserves timestamps and text', () {
    final subtitle = SubtitleFormatAdapter.fromLegacyLyrics(
      track: track,
      lyrics: lyrics,
      origin: SubtitleOrigin.source,
      language: 'ja',
    );

    expect(subtitle.sourceKey, 'asmr_one');
    expect(subtitle.sourceWorkId, 'RJ123456');
    expect(subtitle.trackId, 'track-01');
    expect(subtitle.audioFingerprint, 'audio-hash');
    expect(subtitle.language, 'ja');
    expect(subtitle.segments, hasLength(2));

    final restored = SubtitleFormatAdapter.toLyricLines(subtitle);
    expect(restored, hasLength(2));
    expect(restored[0].startTime, lyrics[0].startTime);
    expect(restored[0].endTime, lyrics[0].endTime);
    expect(restored[0].text, lyrics[0].text);
    expect(restored[1].startTime, lyrics[1].startTime);
    expect(restored[1].endTime, lyrics[1].endTime);
    expect(restored[1].text, lyrics[1].text);
  });

  test('timed subtitle json round-trip preserves provenance', () {
    final original = SubtitleFormatAdapter.fromLegacyLyrics(
      track: track,
      lyrics: lyrics,
      origin: SubtitleOrigin.source,
      language: 'ja',
    );

    final restored = TimedSubtitle.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.origin, SubtitleOrigin.source);
    expect(restored.sourceKey, original.sourceKey);
    expect(restored.sourceWorkId, original.sourceWorkId);
    expect(restored.trackId, original.trackId);
    expect(restored.audioFingerprint, original.audioFingerprint);
    expect(restored.language, original.language);
    expect(restored.segments, original.segments);
    expect(restored.isComplete, isTrue);
  });

  test('subtitle controller contains failures without dropping subtitle data', () {
    final subtitle = SubtitleFormatAdapter.fromLegacyLyrics(
      track: track,
      lyrics: lyrics,
      origin: SubtitleOrigin.source,
    );
    final controller = SubtitleController();

    controller.setOriginal(subtitle);
    controller.setError('subtitle provider failed');

    expect(controller.state.original, subtitle);
    expect(controller.state.errorMessage, 'subtitle provider failed');
    expect(controller.state.isLoading, isFalse);

    controller.dispose();
  });
}
