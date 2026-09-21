import '../models/ai_job_identity.dart';
import '../models/audio_track.dart';
import '../models/lyric.dart';
import 'asr_subtitle_cache.dart';
import 'online_asr_service.dart';

class AsrSubtitleFallbackResult {
  final List<LyricLine> lyrics;
  final bool fromCache;
  final String serviceName;

  const AsrSubtitleFallbackResult({
    required this.lyrics,
    required this.fromCache,
    required this.serviceName,
  });
}

typedef AsrFallbackStatusCallback = void Function(String status);

class AsrSubtitleFallbackService {
  AsrSubtitleFallbackService._();

  static final instance = AsrSubtitleFallbackService._();

  Future<AsrSubtitleFallbackResult?> generate({
    required AudioTrack track,
    AsrFallbackStatusCallback? onStatus,
    bool Function()? isCancelled,
  }) async {
    final identity = TrackIdentity.fromTrack(track);

    onStatus?.call('Memeriksa subtitle Jepang tersimpan…');
    final cached = await AsrSubtitleCache.instance.load(
      track: identity,
      modelName: OnlineAsrService.cacheProfile,
    );
    if (cached != null) {
      return AsrSubtitleFallbackResult(
        lyrics: cached,
        fromCache: true,
        serviceName: 'cache',
      );
    }

    if (isCancelled?.call() == true) return null;

    onStatus?.call('Membuat subtitle Jepang melalui ASR online…');
    final result = await OnlineAsrService.instance.transcribe(
      track,
      isCancelled: isCancelled,
    );
    if (isCancelled?.call() == true) return null;

    final lyrics = result.segments
        .where((segment) => segment.text.trim().isNotEmpty)
        .map(
          (segment) => LyricLine(
            startTime: Duration(
              milliseconds: (segment.startSeconds * 1000).round(),
            ),
            endTime: Duration(
              milliseconds: (segment.endSeconds * 1000).round(),
            ),
            text: segment.text.trim(),
          ),
        )
        .toList(growable: false);

    if (lyrics.isEmpty) return null;

    // Only the small timed text result is cached. No ASR model is stored.
    await AsrSubtitleCache.instance.save(
      track: identity,
      modelName: OnlineAsrService.cacheProfile,
      lines: lyrics,
    );
    if (isCancelled?.call() == true) return null;

    return AsrSubtitleFallbackResult(
      lyrics: List.unmodifiable(lyrics),
      fromCache: false,
      serviceName: result.serviceName,
    );
  }
}
