import '../models/audio_track.dart';

/// Chooses whether a remote track is safe to expose through the byte-stream
/// cache wrapper. Adaptive HLS and the newer external Unified Sources must be
/// handed to the platform player directly so it can resolve manifests,
/// redirects, codecs, and range requests itself.
class AudioStreamStrategy {
  const AudioStreamStrategy._();

  static const Set<String> _directExternalSources = <String>{
    'japanese_asmr',
    'asmr18',
    'asmr_hentai_net',
  };

  static bool shouldTryHeaderAwareFallback(AudioTrack track) {
    final sourceKey = track.sourceKey?.trim().toLowerCase();
    if (sourceKey != 'asmr_hentai_net') return false;

    final uri = Uri.tryParse(track.url);
    final path = uri?.path.toLowerCase() ?? '';
    return path.endsWith('.opus') &&
        track.playbackHeaders.keys.any(
          (key) => key.toLowerCase() == 'referer',
        );
  }

  static bool shouldUseCachingStream(AudioTrack track) {
    final uri = Uri.tryParse(track.url);
    final path = uri?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return false;

    final sourceKey = track.sourceKey?.trim().toLowerCase();
    if (sourceKey != null && _directExternalSources.contains(sourceKey)) {
      return false;
    }

    return true;
  }
}
