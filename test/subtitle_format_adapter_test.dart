import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/lyric/lyric_line.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_format_adapter.dart';

void main() {
  test('existing LyricLine timestamps survive universal subtitle conversion', () {
    const lines = <LyricLine>[
      LyricLine(
        startTime: Duration(milliseconds: 250),
        endTime: Duration(milliseconds: 1750),
        text: 'line one',
      ),
      LyricLine(
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 3),
        text: 'line two',
      ),
    ];

    final subtitle = SubtitleFormatAdapter.fromLyricLines(
      id: 'source-1',
      source: 'asmr_one',
      workId: 'RJ123456',
      trackId: 'track-1',
      language: 'ja',
      generatedBy: 'source',
      lines: lines,
    );
    final restored = SubtitleFormatAdapter.toLyricLines(subtitle);

    expect(restored, lines);
  });
}
