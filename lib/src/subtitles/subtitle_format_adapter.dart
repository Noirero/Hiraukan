import '../models/lyric/lyric_line.dart';
import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';

class SubtitleFormatAdapter {
  const SubtitleFormatAdapter._();

  static List<LyricLine> toLyricLines(TimedSubtitle subtitle) {
    return subtitle.segments
        .map(
          (segment) => LyricLine(
            startTime: segment.start,
            endTime: segment.end,
            text: segment.text,
          ),
        )
        .toList(growable: false);
  }

  static TimedSubtitle fromLyricLines({
    required String id,
    required String source,
    required String workId,
    required String trackId,
    required String language,
    required String generatedBy,
    required List<LyricLine> lines,
  }) {
    return TimedSubtitle(
      id: id,
      source: source,
      workId: workId,
      trackId: trackId,
      language: language,
      generatedBy: generatedBy,
      segments: lines
          .map(
            (line) => SubtitleSegment(
              start: line.startTime,
              end: line.endTime,
              text: line.text,
            ),
          )
          .toList(growable: false),
    );
  }
}
