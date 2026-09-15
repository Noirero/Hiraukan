import 'package:shared_preferences/shared_preferences.dart';

import 'unified_source_models.dart';

class UnifiedSourcePreferences {
  static const _enabledKey = 'unified_sources_enabled_v1';
  static const _preferredKey = 'unified_source_preferred_v1';

  static Future<Set<UnifiedSourceKind>> loadEnabledSources() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_enabledKey);
    if (saved == null || saved.isEmpty) {
      return UnifiedSourceKind.values.toSet();
    }

    final result = UnifiedSourceKind.values
        .where((source) => saved.contains(source.id))
        .toSet();
    return result.isEmpty ? UnifiedSourceKind.values.toSet() : result;
  }

  static Future<void> saveEnabledSources(Set<UnifiedSourceKind> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final safeSources =
        sources.isEmpty ? UnifiedSourceKind.values.toSet() : sources;
    await prefs.setStringList(
      _enabledKey,
      safeSources.map((source) => source.id).toList(growable: false),
    );
  }

  static Future<UnifiedSourceKind?> loadPreferredSource() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferredKey);
    if (saved == null || saved.isEmpty || saved == 'auto') return null;
    for (final source in UnifiedSourceKind.values) {
      if (source.id == saved) return source;
    }
    return null;
  }

  static Future<void> savePreferredSource(UnifiedSourceKind? source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredKey, source?.id ?? 'auto');
  }
}
