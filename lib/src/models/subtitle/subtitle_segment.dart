import 'package:equatable/equatable.dart';

class SubtitleSegment extends Equatable {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  bool get isValid => end.compareTo(start) >= 0 && text.trim().isNotEmpty;

  SubtitleSegment copyWith({
    Duration? start,
    Duration? end,
    String? text,
  }) {
    return SubtitleSegment(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
      };

  factory SubtitleSegment.fromMap(Map<String, dynamic> map) {
    return SubtitleSegment(
      start: Duration(milliseconds: (map['startMs'] as num).toInt()),
      end: Duration(milliseconds: (map['endMs'] as num).toInt()),
      text: map['text']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [start, end, text];
}
