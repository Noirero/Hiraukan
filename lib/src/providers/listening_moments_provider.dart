import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track.dart';
import '../models/listening_moment.dart';
import '../services/listening_moment_service.dart';

class ListeningMomentsState {
  const ListeningMomentsState({
    this.moments = const <ListeningMoment>[],
    this.isLoading = false,
    this.error,
  });

  final List<ListeningMoment> moments;
  final bool isLoading;
  final String? error;

  ListeningMomentsState copyWith({
    List<ListeningMoment>? moments,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ListeningMomentsState(
      moments: moments ?? this.moments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ListeningMomentsNotifier extends StateNotifier<ListeningMomentsState> {
  ListeningMomentsNotifier(this._service)
      : super(const ListeningMomentsState(isLoading: true)) {
    load();
  }

  final ListeningMomentService _service;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      state = ListeningMomentsState(moments: await _service.load());
    } catch (error) {
      state = ListeningMomentsState(
        moments: state.moments,
        error: error.toString(),
      );
    }
  }

  Future<void> add({
    required AudioTrack track,
    required Duration position,
    String note = '',
  }) async {
    final moments = await _service.add(
      state.moments,
      track: track,
      position: position,
      note: note,
    );
    state = state.copyWith(moments: moments, clearError: true);
  }

  Future<void> updateNote(String id, String note) async {
    final moments = await _service.updateNote(state.moments, id, note);
    state = state.copyWith(moments: moments, clearError: true);
  }

  Future<void> delete(String id) async {
    final moments = await _service.delete(state.moments, id);
    state = state.copyWith(moments: moments, clearError: true);
  }
}

final listeningMomentsProvider = StateNotifierProvider<ListeningMomentsNotifier,
    ListeningMomentsState>((ref) {
  return ListeningMomentsNotifier(ListeningMomentService.instance);
});
