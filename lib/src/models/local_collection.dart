import '../models/work.dart';

/// A Hiraukan-owned collection that is independent from any server account.
///
/// Works are stored as snapshots so a collection survives account switching and
/// remains useful for unified/external sources. Playback/detail resolution can
/// hydrate the latest source data when the user opens an item.
class LocalCollection {
  const LocalCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.works = const <Work>[],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Work> works;

  LocalCollection copyWith({
    String? name,
    DateTime? updatedAt,
    List<Work>? works,
  }) {
    return LocalCollection(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      works: works ?? this.works,
    );
  }

  factory LocalCollection.fromJson(Map<String, dynamic> json) {
    return LocalCollection(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      works: (json['works'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((raw) => Work.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'works': works.map((work) => work.toJson()).toList(growable: false),
      };
}
