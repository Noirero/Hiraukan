import 'dart:convert';

import '../models/local_work_mark.dart';
import '../models/work.dart';
import 'log_service.dart';
import 'storage_service.dart';

class LocalWorkMarkService {
  LocalWorkMarkService._();

  static final LocalWorkMarkService instance = LocalWorkMarkService._();
  static const String storageKey = 'hiraukan_local_work_marks_v1';

  String identityFor(Work work) {
    final sourceId = work.sourceId?.trim().toUpperCase();
    if (sourceId != null && sourceId.isNotEmpty) return 'source:$sourceId';

    // Unified-source Work.id values are deterministic and provider-order
    // independent. Using them before sourceUrl also avoids persisting signed or
    // credential-bearing query strings as identity material.
    return 'id:${work.id}';
  }

  LocalWorkMark? find(Iterable<LocalWorkMark> current, Work work) {
    final key = identityFor(work);
    for (final mark in current) {
      if (mark.key == key) return mark;
    }
    return null;
  }

  Future<List<LocalWorkMark>> load() async {
    final raw = StorageService.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <LocalWorkMark>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <LocalWorkMark>[];
      final result = <LocalWorkMark>[];
      final seen = <String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final mark = LocalWorkMark.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (mark.key.isEmpty || !seen.add(mark.key)) continue;
          if (!mark.isFavorite && mark.rating == null) continue;
          result.add(mark);
        } catch (_) {
          // One malformed optional mark should not invalidate the collection.
        }
      }
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (error, stack) {
      LogService.instance.error(
        'Failed to decode local work marks: $error\n$stack',
        tag: 'LocalWorkMarks',
      );
      return const <LocalWorkMark>[];
    }
  }

  Future<void> save(List<LocalWorkMark> marks) async {
    await StorageService.setString(
      storageKey,
      jsonEncode(marks.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  Future<List<LocalWorkMark>> setFavorite(
    List<LocalWorkMark> current,
    Work work,
    bool isFavorite,
  ) {
    return _upsert(
      current,
      work,
      isFavorite: isFavorite,
    );
  }

  Future<List<LocalWorkMark>> setRating(
    List<LocalWorkMark> current,
    Work work,
    int? rating,
  ) async {
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError.value(rating, 'rating', 'Rating must be from 1 to 5');
    }
    return _upsert(
      current,
      work,
      rating: rating,
      replaceRating: true,
    );
  }

  Future<List<LocalWorkMark>> _upsert(
    List<LocalWorkMark> current,
    Work work, {
    bool? isFavorite,
    int? rating,
    bool replaceRating = false,
  }) async {
    final key = identityFor(work);
    final existing = current.where((item) => item.key == key).firstOrNull;
    final nextFavorite = isFavorite ?? existing?.isFavorite ?? false;
    final nextRating = replaceRating ? rating : existing?.rating;
    final next = current.where((item) => item.key != key).toList(growable: true);

    if (nextFavorite || nextRating != null) {
      next.insert(
        0,
        LocalWorkMark(
          key: key,
          work: work,
          isFavorite: nextFavorite,
          rating: nextRating,
          updatedAt: DateTime.now(),
        ),
      );
    }

    await save(next);
    return next;
  }
}
