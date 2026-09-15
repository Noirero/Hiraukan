import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/audio_track.dart';
import '../providers/audio_provider.dart';
import '../providers/lyric_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_transcription_service.dart';
import '../services/kikoflu_feature_coordinator.dart';
import '../services/screen_awake_service.dart';
import 'app_lock_gate.dart';

class ScreenAwakeObserver extends ConsumerStatefulWidget {
  const ScreenAwakeObserver({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<ScreenAwakeObserver> createState() =>
      _ScreenAwakeObserverState();
}

class _ScreenAwakeObserverState extends ConsumerState<ScreenAwakeObserver> {
  bool? _lastRequestedEnabled;
  StreamSubscription<TranscriptionSavedEvent>? _transcriptionSubscription;

  @override
  void initState() {
    super.initState();
    // The coordinator only observes existing Hiraukan services. All imported
    // features remain opt-in and therefore add no source/provider startup work.
    unawaited(KikoFluFeatureCoordinator.instance.initialize());
    _transcriptionSubscription =
        AiTranscriptionService.instance.savedLyrics.listen(_handleSavedLyric);
  }

  Future<void> _handleSavedLyric(TranscriptionSavedEvent event) async {
    if (!mounted) return;
    final track = ref.read(currentTrackProvider).value;
    if (track == null || !_matchesActiveTrack(track, event.audioPath)) return;

    await ref
        .read(lyricControllerProvider.notifier)
        .loadLyricFromLocalFile(event.lrcPath);
  }

  bool _matchesActiveTrack(AudioTrack track, String audioPath) {
    final normalizedAudio = p.normalize(audioPath);
    final sourcePath = track.sourcePath;
    if (sourcePath != null && sourcePath.isNotEmpty) {
      return p.withoutExtension(p.normalize(sourcePath)) ==
          p.withoutExtension(normalizedAudio);
    }

    final uri = Uri.tryParse(track.url);
    if (uri != null && uri.scheme == 'file') {
      try {
        return p.withoutExtension(p.normalize(uri.toFilePath())) ==
            p.withoutExtension(normalizedAudio);
      } catch (_) {}
    }

    // Do not guess from titles alone: different works can contain tracks with
    // the same display name. Exact local-path identity keeps auto-load safe.
    return false;
  }

  @override
  void dispose() {
    unawaited(_transcriptionSubscription?.cancel());
    ScreenAwakeService.setEnabled(false);
    unawaited(KikoFluFeatureCoordinator.instance.dispose());
    super.dispose();
  }

  void _apply(bool enabled) {
    if (_lastRequestedEnabled == enabled) return;
    _lastRequestedEnabled = enabled;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScreenAwakeService.setEnabled(enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final keepAwake = ref.watch(keepScreenAwakeProvider);
    final hasTrack = ref.watch(currentTrackProvider).maybeWhen(
          data: (track) => track != null,
          orElse: () => false,
        );

    _apply(keepAwake && hasTrack);
    return AppLockGate(child: widget.child);
  }
}
