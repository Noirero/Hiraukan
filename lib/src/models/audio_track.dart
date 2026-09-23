import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'audio_track.g.dart';

@JsonSerializable()
class AudioTrack extends Equatable {
  final String id;
  final String title;
  final String url;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final Duration? duration;
  final String? lyricUrl;
  final int? workId;
  final String? hash;
  final String? sourcePath;
  final String? subtitleWorkDirPath;

  /// Stable source namespace used by multi-source-aware caches.
  /// Examples: `asmr_one`, `hentai_asmr`, `ero_voice`.
  final String? sourceKey;

  /// Source-local work identity. This is intentionally a string because not
  /// every provider uses numeric work ids.
  final String? sourceWorkId;

  /// Stable source-local track/chapter identity. Unlike [hash], this may be
  /// unique for multiple virtual tracks that share one physical media URL.
  final String? sourceTrackId;

  /// Absolute offset in the physical source where this logical track starts.
  final Duration? startOffset;

  /// Absolute offset in the physical source where this logical track ends.
  /// When null, the source/player duration is used as the natural end.
  final Duration? endOffset;

  const AudioTrack({
    required this.id,
    required this.title,
    required this.url,
    this.artist,
    this.album,
    this.artworkUrl,
    this.duration,
    this.lyricUrl,
    this.workId,
    this.hash,
    this.sourcePath,
    this.subtitleWorkDirPath,
    this.sourceKey,
    this.sourceWorkId,
    this.sourceTrackId,
    this.startOffset,
    this.endOffset,
  })  : assert(startOffset == null || !startOffset.isNegative),
        assert(endOffset == null || !endOffset.isNegative),
        assert(
          startOffset == null ||
              endOffset == null ||
              endOffset.inMicroseconds >= startOffset.inMicroseconds,
        );

  factory AudioTrack.fromJson(Map<String, dynamic> json) =>
      _$AudioTrackFromJson(json);

  Map<String, dynamic> toJson() => _$AudioTrackToJson(this);

  Duration get segmentStart => startOffset ?? Duration.zero;

  Duration? get segmentEnd => endOffset;

  bool get isSegmented =>
      segmentStart > Duration.zero || segmentEnd != null;

  /// Logical duration shown to the user for a virtual/segmented track.
  Duration? get segmentDuration {
    final end = segmentEnd;
    if (end != null) {
      final value = end - segmentStart;
      return value < Duration.zero ? Duration.zero : value;
    }
    return duration;
  }

  /// Converts an absolute source position to this track's relative position.
  Duration toRelativePosition(Duration absolutePosition) {
    var relative = absolutePosition - segmentStart;
    if (relative < Duration.zero) relative = Duration.zero;
    final maximum = segmentDuration;
    if (maximum != null && relative > maximum) return maximum;
    return relative;
  }

  /// Converts a relative track position to an absolute source position.
  Duration toAbsolutePosition(Duration relativePosition) {
    var relative = relativePosition;
    if (relative < Duration.zero) relative = Duration.zero;
    final maximum = segmentDuration;
    if (maximum != null && relative > maximum) relative = maximum;
    return segmentStart + relative;
  }

  AudioTrack copyWith({
    String? id,
    String? title,
    String? url,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? duration,
    String? lyricUrl,
    int? workId,
    String? hash,
    String? sourcePath,
    String? subtitleWorkDirPath,
    String? sourceKey,
    String? sourceWorkId,
    String? sourceTrackId,
    Duration? startOffset,
    Duration? endOffset,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      duration: duration ?? this.duration,
      lyricUrl: lyricUrl ?? this.lyricUrl,
      workId: workId ?? this.workId,
      hash: hash ?? this.hash,
      sourcePath: sourcePath ?? this.sourcePath,
      subtitleWorkDirPath:
          subtitleWorkDirPath ?? this.subtitleWorkDirPath,
      sourceKey: sourceKey ?? this.sourceKey,
      sourceWorkId: sourceWorkId ?? this.sourceWorkId,
      sourceTrackId: sourceTrackId ?? this.sourceTrackId,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        url,
        artist,
        album,
        artworkUrl,
        duration,
        lyricUrl,
        workId,
        hash,
        sourcePath,
        subtitleWorkDirPath,
        sourceKey,
        sourceWorkId,
        sourceTrackId,
        startOffset,
        endOffset,
      ];
}

@JsonSerializable()
class Playlist extends Equatable {
  final String id;
  final String name;
  final List<AudioTrack> tracks;
  final int currentIndex;

  const Playlist({
    required this.id,
    required this.name,
    required this.tracks,
    this.currentIndex = 0,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  AudioTrack? get currentTrack {
    if (tracks.isEmpty || currentIndex < 0 || currentIndex >= tracks.length) {
      return null;
    }
    return tracks[currentIndex];
  }

  bool get hasNext => currentIndex < tracks.length - 1;
  bool get hasPrevious => currentIndex > 0;

  Playlist copyWith({
    String? id,
    String? name,
    List<AudioTrack>? tracks,
    int? currentIndex,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  List<Object?> get props => [id, name, tracks, currentIndex];
}
