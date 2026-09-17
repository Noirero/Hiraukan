import 'package:equatable/equatable.dart';

import '../models/audio_track.dart';
import 'subtitle_identity.dart';

class SubtitleRequest extends Equatable {
  final AudioTrack track;
  final SubtitleIdentity identity;

  /// null means auto-detect / source default. Never assume Japanese here.
  final String? preferredLanguage;
  final bool allowAi;

  const SubtitleRequest({
    required this.track,
    required this.identity,
    this.preferredLanguage,
    this.allowAi = true,
  });

  factory SubtitleRequest.forTrack(
    AudioTrack track, {
    String? preferredLanguage,
    bool allowAi = true,
  }) {
    return SubtitleRequest(
      track: track,
      identity: SubtitleIdentity.fromTrack(track),
      preferredLanguage: preferredLanguage,
      allowAi: allowAi,
    );
  }

  @override
  List<Object?> get props => [
        track,
        identity,
        preferredLanguage,
        allowAi,
      ];
}
