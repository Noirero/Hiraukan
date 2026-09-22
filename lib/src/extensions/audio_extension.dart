import 'audio_extension_manifest.dart';

enum AudioExtensionHealth {
  healthy,
  degraded,
  broken,
  unknown,
}

enum AudioPlaybackKind {
  direct,
  hls,
}

class AudioExtensionWork {
  final String id;
  final String title;
  final String? canonicalId;
  final String? creator;
  final String? coverUrl;
  final String? description;
  final List<String> tags;
  final int? durationSeconds;
  final String? detailUrl;

  const AudioExtensionWork({
    required this.id,
    required this.title,
    this.canonicalId,
    this.creator,
    this.coverUrl,
    this.description,
    this.tags = const [],
    this.durationSeconds,
    this.detailUrl,
  });
}

class AudioExtensionPage {
  final List<AudioExtensionWork> items;
  final int? totalCount;
  final bool hasMore;

  const AudioExtensionPage({
    required this.items,
    this.totalCount,
    required this.hasMore,
  });
}

class AudioExtensionTrack {
  final String id;
  final String title;
  final int? durationSeconds;
  final String? artworkUrl;
  final String? subtitleUrl;
  final Map<String, String> metadata;

  const AudioExtensionTrack({
    required this.id,
    required this.title,
    this.durationSeconds,
    this.artworkUrl,
    this.subtitleUrl,
    this.metadata = const {},
  });
}

class AudioPlaybackRequest {
  final Uri uri;
  final AudioPlaybackKind kind;
  final Map<String, String> headers;

  const AudioPlaybackRequest({
    required this.uri,
    this.kind = AudioPlaybackKind.direct,
    this.headers = const {},
  });
}

abstract class AudioExtension {
  AudioExtensionManifest get manifest;

  Future<AudioExtensionPage> browse({
    required int page,
    required int pageSize,
  });

  Future<AudioExtensionPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  });

  Future<AudioExtensionWork> getDetail(String workId);

  Future<List<AudioExtensionTrack>> getTracks(String workId);

  Future<AudioPlaybackRequest> resolvePlayback({
    required String workId,
    required String trackId,
  });

  Future<AudioExtensionHealth> checkHealth();
}
