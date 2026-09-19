import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kikoeru_flutter/src/models/lyric.dart';
import 'package:kikoeru_flutter/src/models/subtitle/subtitle_segment.dart';
import 'package:kikoeru_flutter/src/models/subtitle/timed_subtitle.dart';
import 'package:kikoeru_flutter/src/providers/subtitle_display_mode_provider.dart';
import 'package:kikoeru_flutter/src/services/subtitle_translation_cache.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_controller.dart';

TimedSubtitle _subtitle({
  required String id,
  required String trackId,
  required String language,
  required String text,
}) {
  return TimedSubtitle(
    id: id,
    origin: SubtitleOrigin.aiGenerated,
    trackId: trackId,
    language: language,
    segments: [
      SubtitleSegment(
        id: '$id:0',
        start: Duration.zero,
        end: const Duration(seconds: 1),
        text: text,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('subtitle display mode persists explicit bilingual/off choices', () async {
    SharedPreferences.setMockInitialValues({
      'subtitle_display_mode': SubtitleDisplayMode.bilingual.name,
    });

    final notifier = SubtitleDisplayModeNotifier();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state, SubtitleDisplayMode.bilingual);

    await notifier.setMode(SubtitleDisplayMode.off);
    expect(notifier.state, SubtitleDisplayMode.off);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('subtitle_display_mode'),
      SubtitleDisplayMode.off.name,
    );
    notifier.dispose();
  });

  test('universal subtitle controller keeps original and translated separate', () {
    final controller = SubtitleController();
    final original = _subtitle(
      id: 'original',
      trackId: 'track-a',
      language: 'ja',
      text: 'おやすみ',
    );
    final translated = _subtitle(
      id: 'translated',
      trackId: 'track-a',
      language: 'id',
      text: 'Selamat tidur',
    );

    controller.setOriginal(original);
    controller.setTranslated(translated);
    controller.setDisplayMode(SubtitleDisplayMode.bilingual);

    expect(controller.snapshot.primarySubtitle, original);
    expect(controller.snapshot.secondarySubtitle, translated);
  });

  test('translated subtitle from a stale track is rejected', () {
    final controller = SubtitleController();
    controller.setOriginal(
      _subtitle(
        id: 'original-a',
        trackId: 'track-a',
        language: 'ja',
        text: 'A',
      ),
    );

    controller.setTranslated(
      _subtitle(
        id: 'translated-b',
        trackId: 'track-b',
        language: 'id',
        text: 'B',
      ),
    );

    expect(controller.snapshot.translated, isNull);
    expect(controller.snapshot.trackId, 'track-a');
  });

  test('translation document hash changes with source text or timing', () {
    final cache = SubtitleTranslationCache.instance;
    final base = [
      LyricLine(
        startTime: Duration.zero,
        endTime: const Duration(seconds: 1),
        text: 'こんにちは',
      ),
    ];
    final changedText = [
      LyricLine(
        startTime: Duration.zero,
        endTime: const Duration(seconds: 1),
        text: 'こんばんは',
      ),
    ];
    final changedTiming = [
      LyricLine(
        startTime: const Duration(milliseconds: 10),
        endTime: const Duration(seconds: 1),
        text: 'こんにちは',
      ),
    ];

    expect(cache.sourceContentHash(base), cache.sourceContentHash(base));
    expect(
      cache.sourceContentHash(base),
      isNot(cache.sourceContentHash(changedText)),
    );
    expect(
      cache.sourceContentHash(base),
      isNot(cache.sourceContentHash(changedTiming)),
    );
  });
}
