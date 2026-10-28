import 'audio_track.dart';

class ListeningMoment {
  const ListeningMoment({
    required this.id,
    required this.trackIdentity,
    required this.track,
    required this.positionMs,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String trackIdentity;
  final AudioTrack track;
  final int positionMs;
  final DateTime createdAt;
  final String note;

  Duration get position => Duration(
        milliseconds: positionMs < 0 ? 0 : positionMs,
      );

  ListeningMoment copyWith({String? note}) => ListeningMoment(
        id: id,
        trackIdentity: trackIdentity,
        track: track,
        positionMs: positionMs,
        createdAt: createdAt,
        note: note ?? this.note,
      );

  factory ListeningMoment.fromJson(Map<String, dynamic> json) {
    return ListeningMoment(
      id: json['id']?.toString() ?? '',
      trackIdentity: json['trackIdentity']?.toString() ?? '',
      track: AudioTrack.fromJson(
        Map<String, dynamic>.from(json['track'] as Map? ?? const {}),
      ),
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAtMs'] as num?)?.toInt() ?? 0,
      ),
      note: json['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'trackIdentity': trackIdentity,
        'track': track.toJson(),
        'positionMs': positionMs,
        'createdAtMs': createdAt.millisecondsSinceEpoch,
        'note': note,
      };
}
