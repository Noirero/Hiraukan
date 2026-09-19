import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../subtitles/subtitle_controller.dart';

class SubtitleDisplayModeNotifier extends StateNotifier<SubtitleDisplayMode> {
  SubtitleDisplayModeNotifier() : super(SubtitleDisplayMode.original) {
    _load();
  }

  static const _preferenceKey = 'subtitle_display_mode';
  bool _changedLocally = false;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_changedLocally || !mounted) return;
      final saved = prefs.getString(_preferenceKey);
      state = SubtitleDisplayMode.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => SubtitleDisplayMode.original,
      );
    } catch (_) {
      // Keep the safe original-only default.
    }
  }

  Future<void> setMode(SubtitleDisplayMode mode) async {
    _changedLocally = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferenceKey, mode.name);
    } catch (_) {
      // The in-memory mode remains usable even if persistence fails.
    }
  }

  Future<SubtitleDisplayMode> cycleTranslatedModes() async {
    final next = switch (state) {
      SubtitleDisplayMode.off => SubtitleDisplayMode.original,
      SubtitleDisplayMode.original => SubtitleDisplayMode.translated,
      SubtitleDisplayMode.translated => SubtitleDisplayMode.bilingual,
      SubtitleDisplayMode.bilingual => SubtitleDisplayMode.original,
    };
    await setMode(next);
    return next;
  }
}

final subtitleDisplayModeProvider = StateNotifierProvider<
    SubtitleDisplayModeNotifier,
    SubtitleDisplayMode>((ref) {
  return SubtitleDisplayModeNotifier();
});
