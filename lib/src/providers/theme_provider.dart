import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Theme mode. System remains the default so Hiraukan follows the device while
// keeping both the paired light and dark visual identities available.
enum AppThemeMode {
  system,
  light,
  dark,
}

// Color scheme choices. Hiraukan's lavender palette is the default identity,
// while the existing alternatives remain available to users who prefer them.
enum ColorSchemeType {
  oceanBlue,
  forestGreen,
  sunsetOrange,
  lavenderPurple,
  sakuraPink,
  dynamic,
}

class ThemeSettings {
  final AppThemeMode themeMode;
  final ColorSchemeType colorSchemeType;

  const ThemeSettings({
    this.themeMode = AppThemeMode.system,
    this.colorSchemeType = ColorSchemeType.lavenderPurple,
  });

  ThemeSettings copyWith({
    AppThemeMode? themeMode,
    ColorSchemeType? colorSchemeType,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      colorSchemeType: colorSchemeType ?? this.colorSchemeType,
    );
  }

  ThemeMode toThemeMode() {
    switch (themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  static const String _themeModeKey = 'theme_mode';
  static const String _colorSchemeTypeKey = 'color_scheme_type';
  bool _changedLocally = false;

  ThemeSettingsNotifier() : super(const ThemeSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt(_themeModeKey) ?? AppThemeMode.system.index;
    // Do not overwrite an explicit existing color choice. New installs (or
    // installs that never selected a palette) start with Hiraukan lavender.
    final colorSchemeTypeIndex = prefs.getInt(_colorSchemeTypeKey) ??
        ColorSchemeType.lavenderPurple.index;
    if (!mounted || _changedLocally) return;

    final safeThemeModeIndex =
        themeModeIndex.clamp(0, AppThemeMode.values.length - 1).toInt();
    final safeColorSchemeIndex = colorSchemeTypeIndex
        .clamp(0, ColorSchemeType.values.length - 1)
        .toInt();

    state = ThemeSettings(
      themeMode: AppThemeMode.values[safeThemeModeIndex],
      colorSchemeType: ColorSchemeType.values[safeColorSchemeIndex],
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _changedLocally = true;
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setColorSchemeType(ColorSchemeType type) async {
    _changedLocally = true;
    state = state.copyWith(colorSchemeType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorSchemeTypeKey, type.index);
  }

  Future<void> resetToDefault() async {
    _changedLocally = true;
    state = const ThemeSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, AppThemeMode.system.index);
    await prefs.setInt(
      _colorSchemeTypeKey,
      ColorSchemeType.lavenderPurple.index,
    );
  }
}

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>((ref) {
  return ThemeSettingsNotifier();
});
