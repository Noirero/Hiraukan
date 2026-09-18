import 'dart:async';

import 'package:equatable/equatable.dart';

import '../models/subtitle/timed_subtitle.dart';
import 'ai_subtitle_provider.dart';
import 'cached_subtitle_provider.dart';
import 'source_subtitle_provider.dart';
import 'subtitle_presentation.dart';
import 'subtitle_request.dart';
import 'subtitle_translation_cache.dart';
import 'translation_provider.dart';

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

const Object _keepStateValue = Object();

class SubtitleControllerState extends Equatable {
  final SubtitleResolutionStatus status;
  final TimedSubtitle? originalSubtitle;
  final TimedSubtitle? translatedSubtitle;
  final SubtitleResolvedFrom? resolvedFrom;
  final Object? error;
  final SubtitleDisplayMode displayMode;
  final String targetLanguage;
  final SubtitleTranslationStatus translationStatus;
  final Object? translationError;
  final bool translationSupported;

  const SubtitleControllerState({
    this.status = SubtitleResolutionStatus.idle,
    this.originalSubtitle,
    this.translatedSubtitle,
    this.resolvedFrom,
    this.error,
    this.displayMode = SubtitleDisplayMode.original,
    this.targetLanguage = SubtitleTranslationTarget.indonesian,
    this.translationStatus = SubtitleTranslationStatus.idle,
    this.translationError,
    this.translationSupported = false,
  });

  /// Backward-compatible alias for code written before translation state was
  /// introduced. It intentionally always points to the original subtitle.
  TimedSubtitle? get subtitle => originalSubtitle;

  SubtitlePresentation get presentation => SubtitlePresentation(
        mode: displayMode,
        original: originalSubtitle,
        translated: translatedSubtitle,
      );

  bool get translationUnavailable =>
      translationStatus == SubtitleTranslationStatus.unavailable;

  List<SubtitleCcOptionState> get ccOptions {
    final hasOriginal = originalSubtitle != null;
    final sourceOriginalAvailable =
        hasOriginal && resolvedFrom == SubtitleResolvedFrom.source;
    final translationBusy =
        translationStatus == SubtitleTranslationStatus.translating;
    final translationFailure =
        translationStatus == SubtitleTranslationStatus.unavailable;
    final creatingSubtitle = status == SubtitleResolutionStatus.loading;
    final originalIsIndonesian = hasOriginal &&
        SubtitleTranslationCacheKey.normalizeLanguage(
              originalSubtitle!.language,
            ) ==
            SubtitleTranslationTarget.indonesian;
    final indonesianAvailable =
        hasOriginal && (translationSupported || originalIsIndonesian);

    return <SubtitleCcOptionState>[
      SubtitleCcOptionState(
        option: SubtitleCcOption.off,
        label: 'Mati',
        available: true,
        selected: displayMode == SubtitleDisplayMode.off,
      ),
      SubtitleCcOptionState(
        option: SubtitleCcOption.sourceOriginal,
        label: sourceOriginalAvailable
            ? 'Subtitle Asli'
            : 'Subtitle Asli — Tidak tersedia',
        available: sourceOriginalAvailable,
        selected: displayMode == SubtitleDisplayMode.original &&
            sourceOriginalAvailable,
      ),
      SubtitleCcOptionState(
        option: SubtitleCcOption.automaticOriginal,
        label: 'Otomatis — Bahasa Asli',
        available: hasOriginal || creatingSubtitle,
        selected: displayMode == SubtitleDisplayMode.original &&
            !sourceOriginalAvailable,
        busy: creatingSubtitle,
        statusText: creatingSubtitle ? 'Membuat subtitle…' : null,
      ),
      SubtitleCcOptionState(
        option: SubtitleCcOption.automaticIndonesian,
        label: 'Otomatis — Bahasa Indonesia',
        available: indonesianAvailable,
        selected: displayMode == SubtitleDisplayMode.translated &&
            SubtitleTranslationCacheKey.normalizeLanguage(targetLanguage) ==
                SubtitleTranslationTarget.indonesian,
        busy: translationBusy,
        statusText: translationBusy
            ? 'Menerjemahkan…'
            : translationFailure
                ? 'Terjemahan tidak tersedia'
                : null,
      ),
      SubtitleCcOptionState(
        option: SubtitleCcOption.bilingual,
        label: 'Dua Bahasa',
        available: hasOriginal && translationSupported,
        selected: displayMode == SubtitleDisplayMode.bilingual,
        busy: translationBusy,
        statusText: translationBusy
            ? 'Menerjemahkan…'
            : translationFailure
                ? 'Terjemahan tidak tersedia'
                : null,
      ),
      const SubtitleCcOptionState(
        option: SubtitleCcOption.settings,
        label: 'Pengaturan Subtitle',
        available: true,
      ),
    ];
  }

  SubtitleControllerState copyWith({
    SubtitleResolutionStatus? status,
    Object? originalSubtitle = _keepStateValue,
    Object? translatedSubtitle = _keepStateValue,
    Object? resolvedFrom = _keepStateValue,
    Object? error = _keepStateValue,
    SubtitleDisplayMode? displayMode,
    String? targetLanguage,
    SubtitleTranslationStatus? translationStatus,
    Object? translationError = _keepStateValue,
    bool? translationSupported,
  }) {
    return SubtitleControllerState(
      status: status ?? this.status,
      originalSubtitle: identical(originalSubtitle, _keepStateValue)
          ? this.originalSubtitle
          : originalSubtitle as TimedSubtitle?,
      translatedSubtitle: identical(translatedSubtitle, _keepStateValue)
          ? this.translatedSubtitle
          : translatedSubtitle as TimedSubtitle?,
      resolvedFrom: identical(resolvedFrom, _keepStateValue)
          ? this.resolvedFrom
          : resolvedFrom as SubtitleResolvedFrom?,
      error: identical(error, _keepStateValue) ? this.error : error,
      displayMode: displayMode ?? this.displayMode,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      translationStatus: translationStatus ?? this.translationStatus,
      translationError: identical(translationError, _keepStateValue)
          ? this.translationError
          : translationError,
      translationSupported: translationSupported ?? this.translationSupported,
    );
  }

  @override
  List<Object?> get props => [
        status,
        originalSubtitle,
        translatedSubtitle,
        resolvedFrom,
        error,
        displayMode,
        targetLanguage,
        translationStatus,
        translationError,
        translationSupported,
      ];
}

/// Resolves subtitles without ever owning or blocking audio playback.
///
/// Resolution priority is intentionally fixed to:
/// 1. subtitle from the source
/// 2. cached AI/imported subtitle
/// 3. newly generated AI subtitle when allowed
/// 4. no subtitle
///
/// Translation is a separate layer after an original subtitle exists. Changing
/// display mode or translation target never calls source/cache/AI resolution
/// again, so it can never re-run STT by itself.
class SubtitleController {
  final SourceSubtitleProvider sourceProvider;
  final CachedSubtitleProvider cachedProvider;
  final AiSubtitleProvider? aiProvider;
  final TranslationProvider? translationProvider;
  final SubtitleTranslationCache translationCache;

  final StreamController<SubtitleControllerState> _stateController =
      StreamController<SubtitleControllerState>.broadcast();

  SubtitleControllerState _state;
  SubtitleRequest? _currentRequest;
  int _generation = 0;
  int _translationGeneration = 0;
  bool _disposed = false;

  SubtitleController({
    required this.sourceProvider,
    required this.cachedProvider,
    this.aiProvider,
    this.translationProvider,
    SubtitleTranslationCache? translationCache,
  })  : translationCache =
            translationCache ?? SharedPreferencesSubtitleTranslationCache(),
        _state = SubtitleControllerState(
          translationSupported: translationProvider != null,
        );

  SubtitleControllerState get state => _state;
  Stream<SubtitleControllerState> get states => _stateController.stream;

  Future<TimedSubtitle?> resolve(SubtitleRequest request) async {
    final generation = ++_generation;
    _translationGeneration++;
    _currentRequest = request;
    _publish(
      _state.copyWith(
        status: SubtitleResolutionStatus.loading,
        originalSubtitle: null,
        translatedSubtitle: null,
        resolvedFrom: null,
        error: null,
        translationStatus: SubtitleTranslationStatus.idle,
        translationError: null,
        translationSupported: translationProvider != null,
      ),
      generation,
    );

    Object? lastError;

    try {
      final sourceSubtitle = await sourceProvider.load(request);
      if (!_isCurrent(generation)) return null;
      if (sourceSubtitle != null) {
        _acceptOriginal(
          sourceSubtitle,
          SubtitleResolvedFrom.source,
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
        _acceptOriginal(
          cachedSubtitle,
          SubtitleResolvedFrom.cache,
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
          _acceptOriginal(generated, SubtitleResolvedFrom.ai, generation);
          return generated;
        }
      } catch (error) {
        lastError = error;
      }
    }

    _publish(
      _state.copyWith(
        status: SubtitleResolutionStatus.unavailable,
        originalSubtitle: null,
        translatedSubtitle: null,
        resolvedFrom: null,
        error: lastError,
        translationStatus: SubtitleTranslationStatus.idle,
        translationError: null,
      ),
      generation,
    );
    return null;
  }

  /// Changes presentation only. It never calls subtitle resolution or STT.
  Future<void> setDisplayMode(
    SubtitleDisplayMode mode, {
    String? targetLanguage,
  }) async {
    if (_disposed) return;
    final normalizedTarget = SubtitleTranslationCacheKey.normalizeLanguage(
      targetLanguage ?? _state.targetLanguage,
    );
    final targetChanged = normalizedTarget != _state.targetLanguage;

    // Presentation-only mode changes must not invalidate an in-flight
    // translation for the same target. Only a target change makes the current
    // translation stale.
    if (targetChanged) {
      _translationGeneration++;
    }

    _state = _state.copyWith(
      displayMode: mode,
      targetLanguage: normalizedTarget,
      translatedSubtitle: targetChanged ? null : _state.translatedSubtitle,
      translationStatus: targetChanged
          ? SubtitleTranslationStatus.idle
          : _state.translationStatus,
      translationError: targetChanged ? null : _state.translationError,
    );
    _emitCurrent();

    if (_requiresTranslation(mode) && _state.originalSubtitle != null) {
      await _ensureTranslation(_generation);
    }
  }

  /// Updates the target used by translated/bilingual modes without touching
  /// the original subtitle or invoking source/cache/AI providers.
  Future<void> setTranslationTarget(String targetLanguage) {
    return setDisplayMode(
      _state.displayMode,
      targetLanguage: targetLanguage,
    );
  }

  /// Invalidates any in-flight subtitle and translation work. Playback is
  /// unaffected and the user's display preference is retained for next track.
  void cancelCurrent() {
    _generation++;
    _translationGeneration++;
    _currentRequest = null;
    _state = _state.copyWith(
      status: SubtitleResolutionStatus.idle,
      originalSubtitle: null,
      translatedSubtitle: null,
      resolvedFrom: null,
      error: null,
      translationStatus: SubtitleTranslationStatus.idle,
      translationError: null,
    );
    _emitCurrent();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _translationGeneration++;
    _currentRequest = null;
    _stateController.close();
  }

  void _acceptOriginal(
    TimedSubtitle subtitle,
    SubtitleResolvedFrom resolvedFrom,
    int generation,
  ) {
    _publish(
      _state.copyWith(
        status: SubtitleResolutionStatus.ready,
        originalSubtitle: subtitle,
        translatedSubtitle: null,
        resolvedFrom: resolvedFrom,
        error: null,
        translationStatus: SubtitleTranslationStatus.idle,
        translationError: null,
      ),
      generation,
    );

    if (_requiresTranslation(_state.displayMode)) {
      // Translation must not delay the original subtitle becoming usable.
      unawaited(_ensureTranslation(generation));
    }
  }

  Future<void> _ensureTranslation(int generation) async {
    if (!_isCurrent(generation)) return;
    final request = _currentRequest;
    final original = _state.originalSubtitle;
    if (request == null || original == null) return;

    final targetLanguage = SubtitleTranslationCacheKey.normalizeLanguage(
      _state.targetLanguage,
    );

    if (_state.translatedSubtitle != null &&
        SubtitleTranslationCacheKey.normalizeLanguage(
              _state.translatedSubtitle!.language,
            ) ==
            targetLanguage) {
      if (_state.translationStatus != SubtitleTranslationStatus.ready) {
        _state = _state.copyWith(
          translationStatus: SubtitleTranslationStatus.ready,
          translationError: null,
        );
        _emitCurrent();
      }
      return;
    }

    if (_state.translationStatus == SubtitleTranslationStatus.translating) {
      return;
    }

    final translationGeneration = ++_translationGeneration;
    final sourceLanguage = SubtitleTranslationCacheKey.normalizeLanguage(
      original.language,
    );
    if (sourceLanguage == targetLanguage) {
      _publishTranslation(
        original,
        generation,
        translationGeneration,
      );
      return;
    }

    final provider = translationProvider;
    if (provider == null) {
      _publishTranslationUnavailable(
        StateError('Translation provider is not configured.'),
        generation,
        translationGeneration,
      );
      return;
    }

    final cacheKey = SubtitleTranslationCacheKey.fromSubtitle(
      identity: request.identity,
      subtitle: original,
      targetLanguage: targetLanguage,
    );

    try {
      final cached = await translationCache.load(cacheKey);
      if (!_isTranslationCurrent(generation, translationGeneration)) return;
      if (cached != null &&
          _isTranslationForOriginal(cached, original, targetLanguage)) {
        _publishTranslation(cached, generation, translationGeneration);
        return;
      }
    } catch (_) {
      // Translation cache is best-effort and must never hide the original.
    }

    if (!_isTranslationCurrent(generation, translationGeneration)) return;
    _state = _state.copyWith(
      translationStatus: SubtitleTranslationStatus.translating,
      translationError: null,
    );
    _emitCurrent();

    try {
      final translated = await provider.translate(
        original,
        targetLanguage: targetLanguage,
      );
      if (!_isTranslationCurrent(generation, translationGeneration)) return;
      if (!_isTranslationForOriginal(translated, original, targetLanguage)) {
        throw StateError(
          'Translation identity does not match the current subtitle.',
        );
      }

      try {
        await translationCache.save(cacheKey, translated);
      } catch (_) {
        // Cache write failure is isolated from translation display.
      }
      if (!_isTranslationCurrent(generation, translationGeneration)) return;
      _publishTranslation(translated, generation, translationGeneration);
    } catch (error) {
      _publishTranslationUnavailable(
        error,
        generation,
        translationGeneration,
      );
    }
  }

  bool _isTranslationForOriginal(
    TimedSubtitle translated,
    TimedSubtitle original,
    String targetLanguage,
  ) {
    return translated.source == original.source &&
        translated.workId == original.workId &&
        translated.trackId == original.trackId &&
        translated.segments.length == original.segments.length &&
        SubtitleTranslationCacheKey.normalizeLanguage(translated.language) ==
            targetLanguage;
  }

  void _publishTranslation(
    TimedSubtitle translated,
    int generation,
    int translationGeneration,
  ) {
    if (!_isTranslationCurrent(generation, translationGeneration)) return;
    _state = _state.copyWith(
      translatedSubtitle: translated,
      translationStatus: SubtitleTranslationStatus.ready,
      translationError: null,
    );
    _emitCurrent();
  }

  void _publishTranslationUnavailable(
    Object reason,
    int generation,
    int translationGeneration,
  ) {
    if (!_isTranslationCurrent(generation, translationGeneration)) return;
    _state = _state.copyWith(
      translatedSubtitle: null,
      translationStatus: SubtitleTranslationStatus.unavailable,
      translationError: reason,
    );
    _emitCurrent();
  }

  bool _requiresTranslation(SubtitleDisplayMode mode) =>
      mode == SubtitleDisplayMode.translated ||
      mode == SubtitleDisplayMode.bilingual;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  bool _isTranslationCurrent(
    int generation,
    int translationGeneration,
  ) =>
      _isCurrent(generation) &&
      translationGeneration == _translationGeneration;

  void _publish(SubtitleControllerState next, int generation) {
    if (!_isCurrent(generation)) return;
    _state = next;
    _stateController.add(next);
  }

  void _emitCurrent() {
    if (_disposed) return;
    _stateController.add(_state);
  }
}
