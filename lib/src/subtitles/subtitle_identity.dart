import 'package:equatable/equatable.dart';

import '../models/audio_track.dart';

class SubtitleIdentity extends Equatable {
  final String source;
  final String? canonicalWorkId;
  final String? sourceWorkId;
  final String trackId;
  final String? audioFingerprint;

  const SubtitleIdentity({
    required this.source,
    required this.trackId,
    this.canonicalWorkId,
    this.sourceWorkId,
    this.audioFingerprint,
  });

  factory SubtitleIdentity.fromTrack(AudioTrack track) {
    return SubtitleIdentity(
      source: track.sourceKind?.trim().isNotEmpty == true
          ? track.sourceKind!.trim()
          : 'legacy',
      canonicalWorkId: _clean(track.canonicalWorkId),
      sourceWorkId: _clean(track.sourceLocalWorkId) ?? track.workId?.toString(),
      trackId: _clean(track.sourceTrackId) ??
          _clean(track.hash) ??
          track.id,
      audioFingerprint: _clean(track.hash),
    );
  }

  String get effectiveWorkId =>
      canonicalWorkId ?? sourceWorkId ?? 'unknown-work';

  String get stableKey {
    final parts = <String>[
      source,
      effectiveWorkId,
      trackId,
      audioFingerprint ?? '',
    ];
    return parts.map(Uri.encodeComponent).join('|');
  }

  static String? _clean(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  @override
  List<Object?> get props => [
        source,
        canonicalWorkId,
        sourceWorkId,
        trackId,
        audioFingerprint,
      ];
}
