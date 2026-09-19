import 'package:equatable/equatable.dart';

import 'audio_track.dart';

class TrackIdentity extends Equatable {
  final String trackId;
  final String sourceKey;
  final String sourceWorkId;
  final String audioFingerprint;

  const TrackIdentity({
    required this.trackId,
    required this.sourceKey,
    required this.sourceWorkId,
    required this.audioFingerprint,
  });

  factory TrackIdentity.fromTrack(AudioTrack track) {
    return TrackIdentity(
      trackId: track.id,
      sourceKey: track.sourceKey ?? 'legacy',
      sourceWorkId: track.sourceWorkId ?? track.workId?.toString() ?? 'unknown',
      audioFingerprint: track.hash ?? track.id,
    );
  }

  @override
  List<Object?> get props => [trackId, sourceKey, sourceWorkId, audioFingerprint];
}

class GenerationId extends Equatable {
  final TrackIdentity track;
  final int requestId;

  const GenerationId({required this.track, required this.requestId});

  @override
  List<Object?> get props => [track, requestId];
}
