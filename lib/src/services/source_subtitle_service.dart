import 'package:dio/dio.dart';

import '../models/audio_track.dart';
import '../models/lyric.dart';
import '../sources/asmr_hentai_net_source_adapter.dart';
import '../sources/unified_source_models.dart';

class SourceSubtitleResult {
  final List<LyricLine> lyrics;
  final String sourceUri;
  final bool aiGenerated;

  const SourceSubtitleResult({
    required this.lyrics,
    required this.sourceUri,
    required this.aiGenerated,
  });
}

/// Loads subtitles that are supplied by an external audio source itself.
///
/// A source subtitle failure is deliberately non-fatal: callers may continue
/// to the local library and ASR/Whisper fallback paths.
class SourceSubtitleService {
  SourceSubtitleService({Dio? dio}) : _dio = dio ?? Dio();

  static final SourceSubtitleService instance = SourceSubtitleService();

  final Dio _dio;

  Future<SourceSubtitleResult?> load(AudioTrack track) async {
    if (track.sourceKey != UnifiedSourceKind.asmrHentaiNet.id) {
      return null;
    }

    final workId = track.sourceWorkId?.trim();
    final mediaId = track.sourceTrackId?.trim();
    if (workId == null ||
        workId.isEmpty ||
        mediaId == null ||
        mediaId.isEmpty) {
      return null;
    }

    final response = await _dio.post<List<int>>(
      '${AsmrHentaiNetSourceAdapter.apiBaseUrl}/Core/Transcript',
      data: AsmrHentaiApiCodec.encode(
        <String, dynamic>{
          'a': 'ja',
          'b': workId,
          'c': mediaId,
        },
      ),
      options: Options(
        responseType: ResponseType.bytes,
        headers: const <String, String>{
          'Content-Type': 'f/s',
          'Accept-Language': '',
          'User-Agent': 'Hiraukan/3.8 UnifiedSources',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) return null;
    final decoded = AsmrHentaiApiCodec.decode(raw);
    if (decoded is! Map) return null;

    return parseAsmrHentaiTranscript(
      Map<String, dynamic>.from(decoded),
      track: track,
    );
  }

  static SourceSubtitleResult? parseAsmrHentaiTranscript(
    Map<String, dynamic> payload, {
    required AudioTrack track,
  }) {
    final rawLines = payload['b'];
    if (rawLines is! List || rawLines.isEmpty) return null;

    final points = <({Duration start, String text})>[];
    for (final raw in rawLines) {
      if (raw is! Map) continue;
      final entry = Map<String, dynamic>.from(raw);
      final seconds = entry['a'] is num
          ? (entry['a'] as num).toDouble()
          : double.tryParse(entry['a']?.toString() ?? '');
      final text = entry['b']?.toString().trim() ?? '';
      if (seconds == null || seconds < 0 || text.isEmpty) continue;
      points.add(
        (
          start: Duration(milliseconds: (seconds * 1000).round()),
          text: text,
        ),
      );
    }
    if (points.isEmpty) return null;

    points.sort((a, b) => a.start.compareTo(b.start));
    final logicalDuration = track.segmentDuration ?? track.duration;
    final lyrics = <LyricLine>[];

    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      Duration end;
      if (index + 1 < points.length) {
        end = points[index + 1].start;
      } else if (logicalDuration != null &&
          logicalDuration > current.start) {
        end = logicalDuration;
      } else {
        end = current.start + const Duration(seconds: 3);
      }
      if (end <= current.start) {
        end = current.start + const Duration(milliseconds: 500);
      }
      lyrics.add(
        LyricLine(
          startTime: current.start,
          endTime: end,
          text: current.text,
        ),
      );
    }

    final workId = track.sourceWorkId ?? 'unknown';
    final mediaId = track.sourceTrackId ?? track.id;
    final aiFlag = payload['a'];
    final aiGenerated =
        aiFlag == true || aiFlag == 1 || aiFlag?.toString() == '1';

    return SourceSubtitleResult(
      lyrics: List<LyricLine>.unmodifiable(lyrics),
      sourceUri:
          'source://asmr_hentai_net/${Uri.encodeComponent(workId)}/${Uri.encodeComponent(mediaId)}',
      aiGenerated: aiGenerated,
    );
  }
}
