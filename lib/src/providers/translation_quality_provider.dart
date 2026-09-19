import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationQualitySettings {
  final bool contextEnabled;
  final bool playbackPriorityEnabled;

  const TranslationQualitySettings({
    this.contextEnabled = true,
    this.playbackPriorityEnabled = true,
  });

  TranslationQualitySettings copyWith({
    bool? contextEnabled,
    bool? playbackPriorityEnabled,
  }) {
    return TranslationQualitySettings(
      contextEnabled: contextEnabled ?? this.contextEnabled,
      playbackPriorityEnabled:
          playbackPriorityEnabled ?? this.playbackPriorityEnabled,
    );
  }
}

class TranslationQualityNotifier
    extends StateNotifier<TranslationQualitySettings> {
  TranslationQualityNotifier() : super(const TranslationQualitySettings()) {
    _load();
  }

  static const contextKey = 'online_translation_context_enabled';
  static const playbackPriorityKey =
      'online_translation_playback_priority_enabled';
  static const legacyContextKey = 'local_translation_context_enabled';
  static const legacyPlaybackPriorityKey =
      'local_translation_playback_priority_enabled';

  bool _changedByUser = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final context = await _readAndMigrateBool(
        prefs,
        currentKey: contextKey,
        legacyKey: legacyContextKey,
        fallback: true,
      );
      final priority = await _readAndMigrateBool(
        prefs,
        currentKey: playbackPriorityKey,
        legacyKey: legacyPlaybackPriorityKey,
        fallback: true,
      );

      if (_changedByUser || !mounted) return;
      state = TranslationQualitySettings(
        contextEnabled: context,
        playbackPriorityEnabled: priority,
      );
    } catch (_) {
      // Keep safe defaults.
    }
  }

  Future<bool> _readAndMigrateBool(
    SharedPreferences prefs, {
    required String currentKey,
    required String legacyKey,
    required bool fallback,
  }) async {
    final current = prefs.getBool(currentKey);
    if (current != null) return current;

    final legacy = prefs.getBool(legacyKey);
    if (legacy == null) return fallback;

    await prefs.setBool(currentKey, legacy);
    await prefs.remove(legacyKey);
    return legacy;
  }

  Future<void> setContextEnabled(bool value) async {
    _changedByUser = true;
    state = state.copyWith(contextEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(contextKey, value);
    await prefs.remove(legacyContextKey);
  }

  Future<void> setPlaybackPriorityEnabled(bool value) async {
    _changedByUser = true;
    state = state.copyWith(playbackPriorityEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(playbackPriorityKey, value);
    await prefs.remove(legacyPlaybackPriorityKey);
  }
}

final translationQualityProvider = StateNotifierProvider<
    TranslationQualityNotifier,
    TranslationQualitySettings>((ref) {
  return TranslationQualityNotifier();
});
