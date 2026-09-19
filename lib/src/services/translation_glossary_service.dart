import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TranslationGlossaryEntry {
  final String source;
  final String target;

  const TranslationGlossaryEntry({
    required this.source,
    required this.target,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
      };

  factory TranslationGlossaryEntry.fromJson(Map<String, dynamic> json) {
    return TranslationGlossaryEntry(
      source: json['source']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
    );
  }
}

class TranslationGlossarySnapshot {
  final int version;
  final List<TranslationGlossaryEntry> entries;

  const TranslationGlossarySnapshot({
    required this.version,
    required this.entries,
  });
}

class TranslationGlossaryService {
  TranslationGlossaryService._();

  static final TranslationGlossaryService instance =
      TranslationGlossaryService._();

  static const _entriesKey = 'online_translation_glossary_entries_v1';
  static const _versionKey = 'online_translation_glossary_version_v1';
  static const _legacyEntriesKey = 'local_translation_glossary_entries_v1';
  static const _legacyVersionKey = 'local_translation_glossary_version_v1';

  Future<TranslationGlossarySnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_entriesKey);
    var version = prefs.getInt(_versionKey);

    if (raw == null) {
      final legacyRaw = prefs.getString(_legacyEntriesKey);
      final legacyVersion = prefs.getInt(_legacyVersionKey);
      if (legacyRaw != null) {
        raw = legacyRaw;
        version = legacyVersion ?? 1;
        await prefs.setString(_entriesKey, legacyRaw);
        await prefs.setInt(_versionKey, version);
        await prefs.remove(_legacyEntriesKey);
        await prefs.remove(_legacyVersionKey);
      }
    }

    version ??= 1;
    if (raw == null || raw.isEmpty) {
      return TranslationGlossarySnapshot(
        version: version,
        entries: const [],
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return TranslationGlossarySnapshot(
          version: version,
          entries: const [],
        );
      }
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) => TranslationGlossaryEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (entry) =>
                entry.source.trim().isNotEmpty &&
                entry.target.trim().isNotEmpty,
          )
          .toList(growable: false);
      return TranslationGlossarySnapshot(
        version: version,
        entries: entries,
      );
    } catch (_) {
      return TranslationGlossarySnapshot(
        version: version,
        entries: const [],
      );
    }
  }

  Future<TranslationGlossarySnapshot> replaceAll(
    List<TranslationGlossaryEntry> entries,
  ) async {
    final normalized = <TranslationGlossaryEntry>[];
    final seen = <String>{};
    for (final entry in entries) {
      final source = entry.source.trim();
      final target = entry.target.trim();
      if (source.isEmpty || target.isEmpty || !seen.add(source)) continue;
      normalized.add(
        TranslationGlossaryEntry(source: source, target: target),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final nextVersion = (prefs.getInt(_versionKey) ?? 1) + 1;
    await prefs.setString(
      _entriesKey,
      jsonEncode(normalized.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setInt(_versionKey, nextVersion);
    await prefs.remove(_legacyEntriesKey);
    await prefs.remove(_legacyVersionKey);
    return TranslationGlossarySnapshot(
      version: nextVersion,
      entries: List.unmodifiable(normalized),
    );
  }
}
