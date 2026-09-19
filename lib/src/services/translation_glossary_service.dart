import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationGlossaryEntry {
  final String source;
  final String target;

  const TranslationGlossaryEntry({
    required this.source,
    required this.target,
  });

  TranslationGlossaryEntry normalized() => TranslationGlossaryEntry(
        source: source.trim(),
        target: target.trim(),
      );

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

  @override
  bool operator ==(Object other) =>
      other is TranslationGlossaryEntry &&
      other.source == source &&
      other.target == target;

  @override
  int get hashCode => Object.hash(source, target);
}

class ProtectedGlossaryText {
  final String text;
  final Map<String, String> tokenTargets;

  const ProtectedGlossaryText({
    required this.text,
    required this.tokenTargets,
  });

  String restore(String translated) {
    var result = translated;
    for (final entry in tokenTargets.entries) {
      result = result.replaceAll(entry.key, entry.value);

      // Some translation engines insert spaces around unknown tokens.
      final compact = entry.key
          .replaceAll('⟪', '')
          .replaceAll('⟫', '');
      final escapedToken =
          RegExp.escape(compact).replaceAll('_', r'[_\s]*');
      final pattern = RegExp(
        '⟪\\s*$escapedToken\\s*⟫',
        caseSensitive: false,
      );
      result = result.replaceAll(pattern, entry.value);
    }
    return result;
  }
}

class TranslationGlossarySnapshot {
  final List<TranslationGlossaryEntry> entries;
  final String fingerprint;

  const TranslationGlossarySnapshot({
    required this.entries,
    required this.fingerprint,
  });

  ProtectedGlossaryText protect(String sourceText) {
    if (entries.isEmpty || sourceText.isEmpty) {
      return ProtectedGlossaryText(
        text: sourceText,
        tokenTargets: const {},
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => b.source.length.compareTo(a.source.length));

    var prepared = sourceText;
    final tokens = <String, String>{};
    var tokenIndex = 0;

    for (final entry in sorted) {
      if (entry.source.isEmpty || entry.target.isEmpty) continue;
      if (!prepared.contains(entry.source)) continue;

      final token = '⟪HIRAUKAN_GLOSSARY_${tokenIndex++}⟫';
      prepared = prepared.replaceAll(entry.source, token);
      tokens[token] = entry.target;
    }

    return ProtectedGlossaryText(
      text: prepared,
      tokenTargets: Map.unmodifiable(tokens),
    );
  }
}

/// User-owned Japanese -> Indonesian term memory.
///
/// The snapshot is cached in memory, while every mutation is persisted. The
/// deterministic fingerprint is included in translation cache identities so a
/// glossary edit cannot silently reuse older translations.
class TranslationGlossaryService {
  TranslationGlossaryService._();

  static final TranslationGlossaryService instance =
      TranslationGlossaryService._();

  static const _preferenceKey = 'local_translation_glossary_v1';

  TranslationGlossarySnapshot? _cached;

  Future<TranslationGlossarySnapshot> snapshot() async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_preferenceKey);
    final entries = <TranslationGlossaryEntry>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final parsed = TranslationGlossaryEntry.fromJson(
              Map<String, dynamic>.from(item),
            ).normalized();
            if (parsed.source.isEmpty || parsed.target.isEmpty) continue;
            entries.add(parsed);
          }
        }
      } catch (_) {
        // Corrupt preferences are treated as an empty glossary.
      }
    }

    final normalized = _deduplicate(entries);
    final next = TranslationGlossarySnapshot(
      entries: List.unmodifiable(normalized),
      fingerprint: _fingerprint(normalized),
    );
    _cached = next;
    return next;
  }

  Future<TranslationGlossarySnapshot> replace(
    List<TranslationGlossaryEntry> entries,
  ) async {
    final normalized = _deduplicate(
      entries
          .map((entry) => entry.normalized())
          .where((entry) => entry.source.isNotEmpty && entry.target.isNotEmpty)
          .toList(growable: false),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _preferenceKey,
      jsonEncode(normalized.map((entry) => entry.toJson()).toList()),
    );

    final next = TranslationGlossarySnapshot(
      entries: List.unmodifiable(normalized),
      fingerprint: _fingerprint(normalized),
    );
    _cached = next;
    return next;
  }

  Future<TranslationGlossarySnapshot> upsert(
    TranslationGlossaryEntry entry, {
    String? previousSource,
  }) async {
    final current = await snapshot();
    final next = [...current.entries];

    if (previousSource != null) {
      next.removeWhere((item) => item.source == previousSource);
    }

    next.removeWhere((item) => item.source == entry.source.trim());
    next.add(entry.normalized());
    return replace(next);
  }

  Future<TranslationGlossarySnapshot> remove(String source) async {
    final current = await snapshot();
    return replace(
      current.entries.where((entry) => entry.source != source).toList(),
    );
  }

  Future<TranslationGlossarySnapshot> clear() => replace(const []);

  List<TranslationGlossaryEntry> _deduplicate(
    List<TranslationGlossaryEntry> entries,
  ) {
    final bySource = <String, TranslationGlossaryEntry>{};
    for (final entry in entries) {
      bySource[entry.source] = entry;
    }
    final result = bySource.values.toList()
      ..sort((a, b) => a.source.compareTo(b.source));
    return result;
  }

  String _fingerprint(List<TranslationGlossaryEntry> entries) {
    final canonical = [...entries]
      ..sort((a, b) {
        final source = a.source.compareTo(b.source);
        return source != 0 ? source : a.target.compareTo(b.target);
      });
    final text = canonical
        .map((entry) => '${entry.source}\u0000${entry.target}')
        .join('\u0001');
    return sha256.convert(utf8.encode(text)).toString();
  }
}
