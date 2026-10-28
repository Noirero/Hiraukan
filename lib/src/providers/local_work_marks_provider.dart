import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_work_mark.dart';
import '../models/work.dart';
import '../services/local_work_mark_service.dart';

class LocalWorkMarksState {
  const LocalWorkMarksState({
    this.marks = const <LocalWorkMark>[],
    this.isLoading = false,
    this.error,
  });

  final List<LocalWorkMark> marks;
  final bool isLoading;
  final String? error;

  LocalWorkMarksState copyWith({
    List<LocalWorkMark>? marks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LocalWorkMarksState(
      marks: marks ?? this.marks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class LocalWorkMarksNotifier extends StateNotifier<LocalWorkMarksState> {
  LocalWorkMarksNotifier(this._service)
      : super(const LocalWorkMarksState(isLoading: true)) {
    load();
  }

  final LocalWorkMarkService _service;
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
        state = LocalWorkMarksState(marks: await _service.load());
      } catch (error) {
        state = LocalWorkMarksState(
          marks: state.marks,
          error: error.toString(),
        );
      }
    });
  }

  LocalWorkMark? markFor(Work work) => _service.find(state.marks, work);

  bool isFavorite(Work work) => markFor(work)?.isFavorite == true;

  Future<void> setFavorite(Work work, bool value) {
    return _serialize(() async {
      final marks = await _service.setFavorite(state.marks, work, value);
      state = state.copyWith(marks: marks, clearError: true);
    });
  }

  Future<void> toggleFavorite(Work work) {
    return setFavorite(work, !isFavorite(work));
  }

  Future<void> setRating(Work work, int? rating) {
    return _serialize(() async {
      final marks = await _service.setRating(state.marks, work, rating);
      state = state.copyWith(marks: marks, clearError: true);
    });
  }
}

final localWorkMarksProvider =
    StateNotifierProvider<LocalWorkMarksNotifier, LocalWorkMarksState>((ref) {
  return LocalWorkMarksNotifier(LocalWorkMarkService.instance);
});
