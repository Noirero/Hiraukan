import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track.dart';
import '../models/subtitle/timed_subtitle.dart';
import '../subtitles/subtitle_controller.dart';
import '../subtitles/subtitle_format_adapter.dart';
import '../services/subtitle_language_settings.dart';
import 'audio_provider.dart';
import 'lyric_provider.dart';
import 'subtitle_display_mode_provider.dart';

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
      if (controller.snapshot.trackId != track.id) {
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
        language: SubtitleLanguageSettings.instance.sourceLanguage,
      ),
    );

    final translatedLyrics = lyricState.translatedLyrics;
    if (translatedLyrics != null) {
      controller.setTranslated(
        SubtitleFormatAdapter.fromLegacyLyrics(
          track: track,
          lyrics: translatedLyrics,
          origin: SubtitleOrigin.aiGenerated,
          language: SubtitleLanguageSettings.instance.targetLanguage,
          isComplete: !lyricState.isTranslating,
        ),
      );
    } else {
      controller.clearTranslated();
    }

    controller.setDisplayMode(ref.read(subtitleDisplayModeProvider));
    controller.setLoading(
      lyricState.isLoading || lyricState.isTranslating,
      statusMessage: lyricState.isTranslating
          ? 'Menerjemahkan ${lyricState.translatedCount}/${lyricState.translationTotal}'
          : null,
    );
  }

  ref.listen(currentTrackProvider, (_, __) => syncLegacyState());
  ref.listen(lyricControllerProvider, (_, __) => syncLegacyState());
  ref.listen(subtitleDisplayModeProvider, (_, mode) {
    controller.setDisplayMode(mode);
  });

  // The provider can be first read after a track/subtitle is already active.
  // Seed it immediately instead of waiting for the next stream change.
  syncLegacyState();

  return controller;
});

final currentTimedSubtitleProvider = Provider<TimedSubtitle?>((ref) {
  return ref.watch(subtitleControllerProvider).original;
});
