import '../models/audio_track.dart';
import '../models/lyric/lyric_line.dart';
import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';

/// Compatibility adapter between the existing player lyric contract and the
/// new universal subtitle model.
///
/// Stage 1 intentionally keeps [LyricLine] as the renderer-facing type so the
/// player UI does not need to change while subtitle loading is migrated behind
/// a new controller.
class SubtitleFormatAdapter {
  const SubtitleFormatAdapter._();

  static TimedSubtitle fromLegacyLyrics({
    required AudioTrack track,
    required List<LyricLine> lyrics,
    SubtitleOrigin origin = SubtitleOrigin.legacy,
    String? language,
    bool isComplete = true,
  }) {
    final sourceKey = track.sourceKey ?? 'legacy';
    final sourceWorkId =
        track.sourceWorkId ?? track.workId?.toString() ?? 'unknown-work';
    final subtitleId = '$sourceKey:$sourceWorkId:${track.id}:${origin.name}';

    final segments = lyrics.asMap().entries.map((entry) {
      final line = entry.value;
      return SubtitleSegment(
        id: '$subtitleId:${entry.key}:${line.startTime.inMilliseconds}',
        start: line.startTime,
        end: line.endTime,
        text: line.text,
      );
    }).toList(growable: false);

    return TimedSubtitle(
      id: subtitleId,
      origin: origin,
      sourceKey: track.sourceKey,
      workId: track.workId,
      sourceWorkId: track.sourceWorkId,
      trackId: track.id,
      audioFingerprint: track.hash ?? track.id,
      language: language,
      generatedBy: origin == SubtitleOrigin.legacy ? 'legacy-lyric-provider' : null,
      segments: segments,
      isComplete: isComplete,
    );
  }

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
}
