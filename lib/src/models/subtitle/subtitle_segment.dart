import 'package:equatable/equatable.dart';

/// A source-agnostic timed subtitle segment.
///
/// The model deliberately does not depend on LRC/SRT/VTT so transcription,
/// source subtitles, cached subtitles, and translations can share one internal
/// representation.
class SubtitleSegment extends Equatable {
  final String id;
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  }) : assert(!end.isNegative),
       assert(!start.isNegative),
       assert(end >= start);

  SubtitleSegment copyWith({
    String? id,
    Duration? start,
    Duration? end,
    String? text,
  }) {
    return SubtitleSegment(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
      };

  factory SubtitleSegment.fromJson(Map<String, dynamic> json) {
    return SubtitleSegment(
      id: json['id']?.toString() ?? '',
      start: Duration(milliseconds: (json['startMs'] as num?)?.toInt() ?? 0),
      end: Duration(milliseconds: (json['endMs'] as num?)?.toInt() ?? 0),
      text: json['text']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, start, end, text];
}
