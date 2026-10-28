import 'work.dart';

/// Hiraukan-owned personal state for a work.
///
/// This is intentionally local and source-independent. It must never be
/// presented as a rating/favorite mutation on a provider that does not expose
/// that capability.
class LocalWorkMark {
  const LocalWorkMark({
    required this.key,
    required this.work,
    required this.isFavorite,
    required this.updatedAt,
    this.rating,
  });

  final String key;
  final Work work;
  final bool isFavorite;
  final int? rating;
  final DateTime updatedAt;

  LocalWorkMark copyWith({
    Work? work,
    bool? isFavorite,
    int? rating,
    bool clearRating = false,
    DateTime? updatedAt,
  }) {
    return LocalWorkMark(
      key: key,
      work: work ?? this.work,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: clearRating ? null : rating ?? this.rating,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory LocalWorkMark.fromJson(Map<String, dynamic> json) {
    final rawWork = json['work'];
    if (rawWork is! Map) {
      throw const FormatException('Local work mark is missing its work');
    }
    final rating = (json['rating'] as num?)?.toInt();
    return LocalWorkMark(
      key: json['key']?.toString() ?? '',
      work: Work.fromJson(Map<String, dynamic>.from(rawWork)),
      isFavorite: json['isFavorite'] == true,
      rating: rating != null && rating >= 1 && rating <= 5 ? rating : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'work': work.toJson(),
        'isFavorite': isFavorite,
        if (rating != null) 'rating': rating,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}
