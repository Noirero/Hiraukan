import 'package:equatable/equatable.dart';

import 'subtitle_segment.dart';

class TimedSubtitle extends Equatable {
  final String id;
  final String source;
  final String workId;
  final String trackId;
  final String language;
  final String generatedBy;
  final List<SubtitleSegment> segments;
  final bool isComplete;
  final Duration? processedUntil;
  final String? modelId;
  final String? modelVersion;

  const TimedSubtitle({
    required this.id,
    required this.source,
    required this.workId,
    required this.trackId,
    required this.language,
    required this.generatedBy,
    required this.segments,
    this.isComplete = true,
    this.processedUntil,
    this.modelId,
    this.modelVersion,
  });

  TimedSubtitle copyWith({
    String? id,
    String? source,
    String? workId,
    String? trackId,
    String? language,
    String? generatedBy,
    List<SubtitleSegment>? segments,
    bool? isComplete,
    Duration? processedUntil,
    String? modelId,
    String? modelVersion,
  }) {
    return TimedSubtitle(
      id: id ?? this.id,
      source: source ?? this.source,
      workId: workId ?? this.workId,
      trackId: trackId ?? this.trackId,
      language: language ?? this.language,
      generatedBy: generatedBy ?? this.generatedBy,
      segments: segments ?? this.segments,
      isComplete: isComplete ?? this.isComplete,
      processedUntil: processedUntil ?? this.processedUntil,
      modelId: modelId ?? this.modelId,
      modelVersion: modelVersion ?? this.modelVersion,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'source': source,
        'workId': workId,
        'trackId': trackId,
        'language': language,
        'generatedBy': generatedBy,
        'segments': segments.map((segment) => segment.toMap()).toList(),
        'isComplete': isComplete,
        'processedUntilMs': processedUntil?.inMilliseconds,
        'modelId': modelId,
        'modelVersion': modelVersion,
      };

  factory TimedSubtitle.fromMap(Map<String, dynamic> map) {
    final rawSegments = map['segments'];
    return TimedSubtitle(
      id: map['id']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      workId: map['workId']?.toString() ?? '',
      trackId: map['trackId']?.toString() ?? '',
      language: map['language']?.toString() ?? 'und',
      generatedBy: map['generatedBy']?.toString() ?? 'unknown',
      segments: rawSegments is List
          ? rawSegments
              .whereType<Map>()
              .map((item) => SubtitleSegment.fromMap(
                    Map<String, dynamic>.from(item),
                  ))
              .toList(growable: false)
          : const <SubtitleSegment>[],
      isComplete: map['isComplete'] as bool? ?? true,
      processedUntil: map['processedUntilMs'] == null
          ? null
          : Duration(
              milliseconds: (map['processedUntilMs'] as num).toInt(),
            ),
      modelId: map['modelId']?.toString(),
      modelVersion: map['modelVersion']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        source,
        workId,
        trackId,
        language,
        generatedBy,
        segments,
        isComplete,
        processedUntil,
        modelId,
        modelVersion,
      ];
}
