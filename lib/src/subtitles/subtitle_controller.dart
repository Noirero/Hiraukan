import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subtitle/timed_subtitle.dart';

enum SubtitleDisplayMode {
  off,
  original,
  translated,
  bilingual,
}

class SubtitleState extends Equatable {
  final String? trackId;
  final TimedSubtitle? original;
  final TimedSubtitle? translated;
  final SubtitleDisplayMode displayMode;
  final bool isLoading;
  final String? statusMessage;
  final String? errorMessage;

  const SubtitleState({
    this.trackId,
    this.original,
    this.translated,
    this.displayMode = SubtitleDisplayMode.original,
    this.isLoading = false,
    this.statusMessage,
    this.errorMessage,
  });

  TimedSubtitle? get primarySubtitle => switch (displayMode) {
        SubtitleDisplayMode.off => null,
        SubtitleDisplayMode.original => original,
        SubtitleDisplayMode.translated => translated ?? original,
        SubtitleDisplayMode.bilingual => original,
      };

  TimedSubtitle? get secondarySubtitle =>
      displayMode == SubtitleDisplayMode.bilingual ? translated : null;

  @override
  List<Object?> get props => [
        trackId,
        original,
        translated,
        displayMode,
        isLoading,
        statusMessage,
        errorMessage,
      ];
}

/// Source-agnostic subtitle state owner.
///
/// Playback never depends on this controller. Errors and loading states are
/// intentionally contained here so subtitle failures cannot stop audio.
class SubtitleController extends StateNotifier<SubtitleState> {
  SubtitleController() : super(const SubtitleState());

  void setOriginal(TimedSubtitle subtitle) {
    final trackChanged =
        state.trackId != null && state.trackId != subtitle.trackId;
    state = SubtitleState(
      trackId: subtitle.trackId,
      original: subtitle,
      translated: trackChanged ? null : state.translated,
      displayMode: state.displayMode,
      isLoading: false,
      statusMessage: null,
      errorMessage: null,
    );
  }

  void setTranslated(TimedSubtitle subtitle) {
    if (state.trackId != null && subtitle.trackId != state.trackId) return;
    state = SubtitleState(
      trackId: subtitle.trackId,
      original: state.original,
      translated: subtitle,
      displayMode: state.displayMode,
      isLoading: state.isLoading,
      statusMessage: state.statusMessage,
      errorMessage: state.errorMessage,
    );
  }

  void setDisplayMode(SubtitleDisplayMode mode) {
    state = SubtitleState(
      trackId: state.trackId,
      original: state.original,
      translated: state.translated,
      displayMode: mode,
      isLoading: state.isLoading,
      statusMessage: state.statusMessage,
      errorMessage: state.errorMessage,
    );
  }

  void setLoading(bool loading, {String? statusMessage}) {
    state = SubtitleState(
      trackId: state.trackId,
      original: state.original,
      translated: state.translated,
      displayMode: state.displayMode,
      isLoading: loading,
      statusMessage: statusMessage ?? (loading ? state.statusMessage : null),
      errorMessage: loading ? null : state.errorMessage,
    );
  }

  void setStatus(String? message) {
    state = SubtitleState(
      trackId: state.trackId,
      original: state.original,
      translated: state.translated,
      displayMode: state.displayMode,
      isLoading: state.isLoading,
      statusMessage: message,
      errorMessage: state.errorMessage,
    );
  }

  void setError(String message) {
    state = SubtitleState(
      trackId: state.trackId,
      original: state.original,
      translated: state.translated,
      displayMode: state.displayMode,
      isLoading: false,
      statusMessage: null,
      errorMessage: message,
    );
  }

  void clearForTrack(String? trackId) {
    state = SubtitleState(
      trackId: trackId,
      displayMode: state.displayMode,
    );
  }

  void clear() => clearForTrack(null);
}
