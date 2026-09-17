import 'package:equatable/equatable.dart';

import 'subtitle_segment.dart';

enum SubtitleOrigin {
  source,
  library,
  aiCache,
  aiGenerated,
  manual,
  legacy,
}

/// Universal subtitle document used inside Hiraukan.
///
/// This carries identity and provenance separately from the segment payload so
/// source subtitles, AI output, cached output, and translated output can be
/// routed without binding the player to a file format.
class TimedSubtitle extends Equatable {
  final String id;
  final SubtitleOrigin origin;
  final String? sourceKey;
  final int? workId;
  final String? sourceWorkId;
  final String trackId;
  final String? audioFingerprint;
  final String? language;
  final String? generatedBy;
  final String? modelId;
  final String? modelVersion;
  final List<SubtitleSegment> segments;
  final bool isComplete;
  final Duration processedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimedSubtitle({
    required this.id,
    required this.origin,
    required this.trackId,
    required List<SubtitleSegment> segments,
    this.sourceKey,
    this.workId,
    this.sourceWorkId,
    this.audioFingerprint,
    this.language,
    this.generatedBy,
    this.modelId,
    this.modelVersion,
    this.isComplete = true,
    Duration? processedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : segments = List.unmodifiable(segments),
        processedUntil = processedUntil ?? _coverageEnd(segments),
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now().toUtc();

  bool get isEmpty => segments.isEmpty;

  Duration get coverageEnd => _coverageEnd(segments);

  TimedSubtitle copyWith({
    String? id,
    SubtitleOrigin? origin,
    String? sourceKey,
    int? workId,
    String? sourceWorkId,
    String? trackId,
    String? audioFingerprint,
    String? language,
    String? generatedBy,
    String? modelId,
    String? modelVersion,
    List<SubtitleSegment>? segments,
    bool? isComplete,
    Duration? processedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimedSubtitle(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      sourceKey: sourceKey ?? this.sourceKey,
      workId: workId ?? this.workId,
      sourceWorkId: sourceWorkId ?? this.sourceWorkId,
      trackId: trackId ?? this.trackId,
      audioFingerprint: audioFingerprint ?? this.audioFingerprint,
      language: language ?? this.language,
      generatedBy: generatedBy ?? this.generatedBy,
      modelId: modelId ?? this.modelId,
      modelVersion: modelVersion ?? this.modelVersion,
      segments: segments ?? this.segments,
      isComplete: isComplete ?? this.isComplete,
      processedUntil: processedUntil ?? this.processedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'origin': origin.name,
        'sourceKey': sourceKey,
        'workId': workId,
        'sourceWorkId': sourceWorkId,
        'trackId': trackId,
        'audioFingerprint': audioFingerprint,
        'language': language,
        'generatedBy': generatedBy,
        'modelId': modelId,
        'modelVersion': modelVersion,
        'segments': segments.map((segment) => segment.toJson()).toList(),
        'isComplete': isComplete,
        'processedUntilMs': processedUntil.inMilliseconds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TimedSubtitle.fromJson(Map<String, dynamic> json) {
    final rawSegments = json['segments'];
    final segments = rawSegments is List
        ? rawSegments
            .whereType<Map>()
            .map(
              (item) => SubtitleSegment.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false)
        : const <SubtitleSegment>[];
    final originName = json['origin']?.toString();
    final origin = SubtitleOrigin.values.firstWhere(
      (value) => value.name == originName,
      orElse: () => SubtitleOrigin.legacy,
    );

    return TimedSubtitle(
      id: json['id']?.toString() ?? '',
      origin: origin,
      sourceKey: json['sourceKey']?.toString(),
      workId: (json['workId'] as num?)?.toInt(),
      sourceWorkId: json['sourceWorkId']?.toString(),
      trackId: json['trackId']?.toString() ?? '',
      audioFingerprint: json['audioFingerprint']?.toString(),
      language: json['language']?.toString(),
      generatedBy: json['generatedBy']?.toString(),
      modelId: json['modelId']?.toString(),
      modelVersion: json['modelVersion']?.toString(),
      segments: segments,
      isComplete: json['isComplete'] as bool? ?? true,
      processedUntil: Duration(
        milliseconds: (json['processedUntilMs'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  static Duration _coverageEnd(List<SubtitleSegment> segments) {
    var end = Duration.zero;
    for (final segment in segments) {
      if (segment.end > end) end = segment.end;
    }
    return end;
  }

  @override
  List<Object?> get props => [
        id,
        origin,
        sourceKey,
        workId,
        sourceWorkId,
        trackId,
        audioFingerprint,
        language,
        generatedBy,
        modelId,
        modelVersion,
        segments,
        isComplete,
        processedUntil,
        createdAt,
        updatedAt,
      ];
}
