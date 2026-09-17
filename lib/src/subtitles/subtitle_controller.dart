import 'dart:async';

import 'package:equatable/equatable.dart';

import '../models/subtitle/timed_subtitle.dart';
import 'ai_subtitle_provider.dart';
import 'cached_subtitle_provider.dart';
import 'source_subtitle_provider.dart';
import 'subtitle_request.dart';

enum SubtitleResolutionStatus {
  idle,
  loading,
  ready,
  unavailable,
}

enum SubtitleResolvedFrom {
  source,
  cache,
  ai,
}

class SubtitleControllerState extends Equatable {
  final SubtitleResolutionStatus status;
  final TimedSubtitle? subtitle;
  final SubtitleResolvedFrom? resolvedFrom;
  final Object? error;

  const SubtitleControllerState({
    this.status = SubtitleResolutionStatus.idle,
    this.subtitle,
    this.resolvedFrom,
    this.error,
  });

  const SubtitleControllerState.loading()
      : status = SubtitleResolutionStatus.loading,
        subtitle = null,
        resolvedFrom = null,
        error = null;

  const SubtitleControllerState.ready(
    TimedSubtitle value,
    SubtitleResolvedFrom source,
  )   : status = SubtitleResolutionStatus.ready,
        subtitle = value,
        resolvedFrom = source,
        error = null;

  const SubtitleControllerState.unavailable([Object? reason])
      : status = SubtitleResolutionStatus.unavailable,
        subtitle = null,
        resolvedFrom = null,
        error = reason;

  @override
  List<Object?> get props => [status, subtitle, resolvedFrom, error];
}

/// Resolves subtitles without ever owning or blocking audio playback.
///
/// Priority is intentionally fixed to:
/// 1. subtitle from the source
/// 2. cached AI/imported subtitle
/// 3. newly generated AI subtitle when allowed
/// 4. no subtitle
class SubtitleController {
  final SourceSubtitleProvider sourceProvider;
  final CachedSubtitleProvider cachedProvider;
  final AiSubtitleProvider? aiProvider;

  final StreamController<SubtitleControllerState> _stateController =
      StreamController<SubtitleControllerState>.broadcast();

  SubtitleControllerState _state = const SubtitleControllerState();
  int _generation = 0;
  bool _disposed = false;

  SubtitleController({
    required this.sourceProvider,
    required this.cachedProvider,
    this.aiProvider,
  });

  SubtitleControllerState get state => _state;
  Stream<SubtitleControllerState> get states => _stateController.stream;

  Future<TimedSubtitle?> resolve(SubtitleRequest request) async {
    final generation = ++_generation;
    _publish(const SubtitleControllerState.loading(), generation);

    Object? lastError;

    try {
      final sourceSubtitle = await sourceProvider.load(request);
      if (!_isCurrent(generation)) return null;
      if (sourceSubtitle != null) {
        _publish(
          SubtitleControllerState.ready(
            sourceSubtitle,
            SubtitleResolvedFrom.source,
          ),
          generation,
        );
        return sourceSubtitle;
      }
    } catch (error) {
      lastError = error;
    }

    try {
      final cachedSubtitle = await cachedProvider.load(request);
      if (!_isCurrent(generation)) return null;
      if (cachedSubtitle != null) {
        _publish(
          SubtitleControllerState.ready(
            cachedSubtitle,
            SubtitleResolvedFrom.cache,
          ),
          generation,
        );
        return cachedSubtitle;
      }
    } catch (error) {
      lastError = error;
    }

    final ai = aiProvider;
    if (request.allowAi && ai != null) {
      try {
        final generated = await ai.generate(request);
        if (!_isCurrent(generation)) return null;
        if (generated != null) {
          // Caching is best-effort. A cache write failure must not hide a
          // subtitle that was successfully generated.
          try {
            await cachedProvider.save(request, generated);
          } catch (_) {
            // Intentionally isolated from playback/subtitle display.
          }
          if (!_isCurrent(generation)) return null;
          _publish(
            SubtitleControllerState.ready(
              generated,
              SubtitleResolvedFrom.ai,
            ),
            generation,
          );
          return generated;
        }
      } catch (error) {
        lastError = error;
      }
    }

    _publish(SubtitleControllerState.unavailable(lastError), generation);
    return null;
  }

  /// Invalidates any in-flight subtitle work. Playback is unaffected.
  void cancelCurrent() {
    _generation++;
    _publish(const SubtitleControllerState(), _generation);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _stateController.close();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _publish(SubtitleControllerState next, int generation) {
    if (!_isCurrent(generation)) return;
    _state = next;
    _stateController.add(next);
  }
}
