import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  static const String _localeLanguageKey = 'locale_language';
  static const String _localeScriptKey = 'locale_script';
  static const String _followSystemKey = 'locale_follow_system';

  /// Bahasa Indonesia is the default Hiraukan locale.
  /// `null` is reserved for users who explicitly choose Follow System.
  LocaleNotifier() : super(const Locale('id')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_followSystemKey) == true) {
      state = null;
      return;
    }

    final language = prefs.getString(_localeLanguageKey);
    if (language == null) {
      // New installs and users without an explicit language preference use
      // Indonesian. This keeps metadata untouched while making app chrome,
      // settings, errors, and feature UI Indonesia-first.
      state = const Locale('id');
      return;
    }

    final script = prefs.getString(_localeScriptKey);
    state = script != null
        ? Locale.fromSubtags(languageCode: language, scriptCode: script)
        : Locale(language);
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.setBool(_followSystemKey, true);
      await prefs.remove(_localeLanguageKey);
      await prefs.remove(_localeScriptKey);
    } else {
      await prefs.setBool(_followSystemKey, false);
      await prefs.setString(_localeLanguageKey, locale.languageCode);
      if (locale.scriptCode != null) {
        await prefs.setString(_localeScriptKey, locale.scriptCode!);
      } else {
        await prefs.remove(_localeScriptKey);
      }
    }
    state = locale;
  }
}

/// null = explicitly follow system locale; Indonesian is the app default.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});
