import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track.dart';
import '../models/subtitle/timed_subtitle.dart';
import '../subtitles/subtitle_controller.dart';
import '../subtitles/subtitle_format_adapter.dart';
import 'audio_provider.dart';
import 'lyric_provider.dart';

/// Transitional bridge that mirrors the existing LyricController state into
/// the new universal subtitle model.
///
/// Existing player widgets can continue consuming LyricController while new
/// subtitle features are built against SubtitleController. Once all providers
/// have migrated, this compatibility bridge can be removed without changing
/// the player renderer.
final subtitleControllerProvider =
    StateNotifierProvider<SubtitleController, SubtitleState>((ref) {
  final controller = SubtitleController();

  void syncLegacyState() {
    final AudioTrack? track = ref.read(currentTrackProvider).value;
    final lyricState = ref.read(lyricControllerProvider);

    if (track == null) {
      controller.clear();
      return;
    }

    if (lyricState.lyrics.isEmpty) {
      if (controller.state.trackId != track.id) {
        controller.clearForTrack(track.id);
      }
      controller.setLoading(lyricState.isLoading);
      final error = lyricState.error;
      if (error != null && error.isNotEmpty) {
        controller.setError(error);
      }
      return;
    }

    final origin = lyricState.lyricUrl == null
        ? SubtitleOrigin.library
        : SubtitleOrigin.source;
    controller.setOriginal(
      SubtitleFormatAdapter.fromLegacyLyrics(
        track: track,
        lyrics: lyricState.lyrics,
        origin: origin,
      ),
    );
    controller.setLoading(lyricState.isLoading);
  }

  ref.listen(currentTrackProvider, (_, __) => syncLegacyState());
  ref.listen(lyricControllerProvider, (_, __) => syncLegacyState());

  return controller;
});

final currentTimedSubtitleProvider = Provider<TimedSubtitle?>((ref) {
  return ref.watch(subtitleControllerProvider).original;
});
