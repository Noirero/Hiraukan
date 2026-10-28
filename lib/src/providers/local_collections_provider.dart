import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_collection.dart';
import '../models/work.dart';
import '../services/local_collection_service.dart';

class LocalCollectionsState {
  const LocalCollectionsState({
    this.collections = const <LocalCollection>[],
    this.isLoading = false,
    this.error,
  });

  final List<LocalCollection> collections;
  final bool isLoading;
  final String? error;

  LocalCollectionsState copyWith({
    List<LocalCollection>? collections,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LocalCollectionsState(
      collections: collections ?? this.collections,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LocalCollectionsNotifier extends StateNotifier<LocalCollectionsState> {
  LocalCollectionsNotifier(this._service)
      : super(const LocalCollectionsState(isLoading: true)) {
    load();
  }

  final LocalCollectionService _service;
  Future<void> _operationTail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<void> load() {
    return _serialize(() async {
      state = state.copyWith(isLoading: true, clearError: true);
      try {
        final collections = await _service.load();
        state = LocalCollectionsState(collections: collections);
      } catch (error) {
        state = LocalCollectionsState(
          collections: state.collections,
          error: error.toString(),
        );
      }
    });
  }

  Future<LocalCollection> create(String name) {
    return _serialize(() async {
      final collection = await _service.create(state.collections, name);
      state = state.copyWith(
        collections: <LocalCollection>[...state.collections, collection],
        clearError: true,
      );
      return collection;
    });
  }

  Future<void> rename(String id, String name) {
    return _serialize(() async {
      final collections = await _service.rename(state.collections, id, name);
      state = state.copyWith(collections: collections, clearError: true);
    });
  }

  Future<void> delete(String id) {
    return _serialize(() async {
      final collections = await _service.delete(state.collections, id);
      state = state.copyWith(collections: collections, clearError: true);
    });
  }

  Future<void> addWork(String collectionId, Work work) {
    return _serialize(() async {
      final collections = await _service.addWork(
        state.collections,
        collectionId,
        work,
      );
      state = state.copyWith(collections: collections, clearError: true);
    });
  }

  Future<void> removeWork(String collectionId, Work work) {
    return _serialize(() async {
      final collections = await _service.removeWork(
        state.collections,
        collectionId,
        work,
      );
      state = state.copyWith(collections: collections, clearError: true);
    });
  }

  bool contains(String collectionId, Work work) {
    final collection = state.collections
        .where((item) => item.id == collectionId)
        .firstOrNull;
    if (collection == null) return false;
    return _service.contains(collection, work);
  }
}

final localCollectionsProvider = StateNotifierProvider<LocalCollectionsNotifier,
    LocalCollectionsState>((ref) {
  return LocalCollectionsNotifier(LocalCollectionService.instance);
});
