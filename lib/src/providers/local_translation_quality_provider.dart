import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalTranslationQualitySettings {
  final bool contextEnabled;
  final bool playbackPriorityEnabled;

  const LocalTranslationQualitySettings({
    this.contextEnabled = true,
    this.playbackPriorityEnabled = true,
  });

  LocalTranslationQualitySettings copyWith({
    bool? contextEnabled,
    bool? playbackPriorityEnabled,
  }) {
    return LocalTranslationQualitySettings(
      contextEnabled: contextEnabled ?? this.contextEnabled,
      playbackPriorityEnabled:
          playbackPriorityEnabled ?? this.playbackPriorityEnabled,
    );
  }
}

class LocalTranslationQualityNotifier
    extends StateNotifier<LocalTranslationQualitySettings> {
  LocalTranslationQualityNotifier()
      : super(const LocalTranslationQualitySettings()) {
    _load();
  }

  static const _contextKey = 'local_translation_context_enabled';
  static const _priorityKey = 'local_translation_playback_priority_enabled';
  bool _changedLocally = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_changedLocally || !mounted) return;
      state = LocalTranslationQualitySettings(
        contextEnabled: prefs.getBool(_contextKey) ?? true,
        playbackPriorityEnabled: prefs.getBool(_priorityKey) ?? true,
      );
    } catch (_) {
      // Keep safe defaults.
    }
  }

  Future<void> setContextEnabled(bool value) async {
    _changedLocally = true;
    state = state.copyWith(contextEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contextKey, value);
  }

  Future<void> setPlaybackPriorityEnabled(bool value) async {
    _changedLocally = true;
    state = state.copyWith(playbackPriorityEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_priorityKey, value);
  }
}

final localTranslationQualityProvider = StateNotifierProvider<
    LocalTranslationQualityNotifier,
    LocalTranslationQualitySettings>((ref) {
  return LocalTranslationQualityNotifier();
});
