import 'dart:convert';

import '../models/local_collection.dart';
import '../models/work.dart';
import 'log_service.dart';
import 'storage_service.dart';

class LocalCollectionService {
  LocalCollectionService._();

  static final LocalCollectionService instance = LocalCollectionService._();
  static const String _storageKey = 'hiraukan_local_collections_v1';

  Future<List<LocalCollection>> load() async {
    final raw = StorageService.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const <LocalCollection>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <LocalCollection>[];
      final collections = decoded
          .whereType<Map>()
          .map((item) => LocalCollection.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((item) => item.id.isNotEmpty && item.name.trim().isNotEmpty)
          .toList(growable: false);
      return collections;
    } catch (error, stack) {
      LogService.instance.error(
        'Failed to decode local collections: $error\n$stack',
        tag: 'LocalCollections',
      );
      return const <LocalCollection>[];
    }
  }

  Future<void> save(List<LocalCollection> collections) async {
    await StorageService.setString(
      _storageKey,
      jsonEncode(collections.map((item) => item.toJson()).toList()),
    );
  }

  Future<LocalCollection> create(
    List<LocalCollection> current,
    String name,
  ) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Collection name cannot be empty');
    }
    if (current.any(
      (item) => item.name.trim().toLowerCase() == normalized.toLowerCase(),
    )) {
      throw StateError('A collection with this name already exists');
    }

    final now = DateTime.now();
    final collection = LocalCollection(
      id: '${now.microsecondsSinceEpoch}',
      name: normalized,
      createdAt: now,
      updatedAt: now,
    );
    await save(<LocalCollection>[...current, collection]);
    return collection;
  }

  Future<List<LocalCollection>> rename(
    List<LocalCollection> current,
    String id,
    String name,
  ) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Collection name cannot be empty');
    }
    if (current.any(
      (item) =>
          item.id != id &&
          item.name.trim().toLowerCase() == normalized.toLowerCase(),
    )) {
      throw StateError('A collection with this name already exists');
    }

    final now = DateTime.now();
    final next = current
        .map(
          (item) => item.id == id
              ? item.copyWith(name: normalized, updatedAt: now)
              : item,
        )
        .toList(growable: false);
    await save(next);
    return next;
  }

  Future<List<LocalCollection>> delete(
    List<LocalCollection> current,
    String id,
  ) async {
    final next = current.where((item) => item.id != id).toList(growable: false);
    await save(next);
    return next;
  }

  Future<List<LocalCollection>> addWork(
    List<LocalCollection> current,
    String id,
    Work work,
  ) async {
    final now = DateTime.now();
    final key = _workKey(work);
    final next = current.map((item) {
      if (item.id != id) return item;
      final existing = item.works.indexWhere((candidate) => _workKey(candidate) == key);
      final works = item.works.toList(growable: true);
      if (existing >= 0) {
        works[existing] = work;
      } else {
        works.insert(0, work);
      }
      return item.copyWith(works: works, updatedAt: now);
    }).toList(growable: false);
    await save(next);
    return next;
  }

  Future<List<LocalCollection>> removeWork(
    List<LocalCollection> current,
    String id,
    Work work,
  ) async {
    final key = _workKey(work);
    final now = DateTime.now();
    final next = current.map((item) {
      if (item.id != id) return item;
      final works = item.works
          .where((candidate) => _workKey(candidate) != key)
          .toList(growable: false);
      return item.copyWith(works: works, updatedAt: now);
    }).toList(growable: false);
    await save(next);
    return next;
  }

  bool contains(LocalCollection collection, Work work) {
    final key = _workKey(work);
    return collection.works.any((candidate) => _workKey(candidate) == key);
  }

  String _workKey(Work work) {
    final sourceId = work.sourceId?.trim().toUpperCase();
    if (sourceId != null && sourceId.isNotEmpty) return 'source:$sourceId';
    final sourceUrl = work.sourceUrl?.trim();
    if (sourceUrl != null && sourceUrl.isNotEmpty) return 'url:$sourceUrl';
    return 'id:${work.id}';
  }
}
