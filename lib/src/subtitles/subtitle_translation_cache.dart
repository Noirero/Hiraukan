import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subtitle/timed_subtitle.dart';
import 'subtitle_identity.dart';

class SubtitleTranslationCacheKey extends Equatable {
  final String source;
  final String workId;
  final String trackId;
  final String sourceLanguage;
  final String targetLanguage;
  final String contentIdentity;

  const SubtitleTranslationCacheKey({
    required this.source,
    required this.workId,
    required this.trackId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.contentIdentity,
  });

  factory SubtitleTranslationCacheKey.fromSubtitle({
    required SubtitleIdentity identity,
    required TimedSubtitle subtitle,
    required String targetLanguage,
  }) {
    final identitySource = identity.source.trim();
    final identityWorkId = _firstNonEmpty(<String?>[
      identity.canonicalWorkId,
      identity.sourceWorkId,
    ]);

    return SubtitleTranslationCacheKey(
      source: _clean(
        identitySource == 'legacy' ? '' : identitySource,
        fallback: subtitle.source,
      ),
      workId: _clean(identityWorkId ?? '', fallback: subtitle.workId),
      trackId: _clean(identity.trackId, fallback: subtitle.trackId),
      sourceLanguage: normalizeLanguage(subtitle.language),
      targetLanguage: normalizeLanguage(targetLanguage),
      contentIdentity: contentFingerprint(subtitle),
    );
  }

  String get stableKey => <String>[
        source,
        workId,
        trackId,
        sourceLanguage,
        targetLanguage,
        contentIdentity,
      ].map(Uri.encodeComponent).join('|');

  String get storageKey =>
      'subtitle_translation_cache_v1_${_fnv1a32(stableKey)}';

  static String normalizeLanguage(String value) {
    final normalized = value.trim().replaceAll('_', '-').toLowerCase();
    return normalized.isEmpty ? 'und' : normalized;
  }

  static String contentFingerprint(TimedSubtitle subtitle) {
    final buffer = StringBuffer()
      ..write(subtitle.id)
      ..write('|')
      ..write(subtitle.language)
      ..write('|')
      ..write(subtitle.isComplete ? '1' : '0');
    for (final segment in subtitle.segments) {
      buffer
        ..write('|')
        ..write(segment.start.inMilliseconds)
        ..write(':')
        ..write(segment.end.inMilliseconds)
        ..write(':')
        ..write(segment.text);
    }
    return _fnv1a32(buffer.toString());
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final cleaned = value?.trim();
      if (cleaned != null && cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  static String _clean(String value, {required String fallback}) {
    final cleaned = value.trim();
    if (cleaned.isNotEmpty) return cleaned;
    final fallbackCleaned = fallback.trim();
    return fallbackCleaned.isEmpty ? 'unknown' : fallbackCleaned;
  }

  static String _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  @override
  List<Object?> get props => [
        source,
        workId,
        trackId,
        sourceLanguage,
        targetLanguage,
        contentIdentity,
      ];
}

abstract class SubtitleTranslationCache {
  Future<TimedSubtitle?> load(SubtitleTranslationCacheKey key);

  Future<void> save(
    SubtitleTranslationCacheKey key,
    TimedSubtitle translatedSubtitle,
  );
}

/// Persistent cache kept independently from AI model files.
///
/// A stored entry contains its full stable identity as well as the hashed
/// preference key, so a hash collision cannot silently return another track's
/// translation.
class SharedPreferencesSubtitleTranslationCache
    implements SubtitleTranslationCache {
  @override
  Future<TimedSubtitle?> load(SubtitleTranslationCacheKey key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key.storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      if (data['stableKey']?.toString() != key.stableKey) return null;
      final subtitle = data['subtitle'];
      if (subtitle is! Map) return null;
      return TimedSubtitle.fromMap(Map<String, dynamic>.from(subtitle));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(
    SubtitleTranslationCacheKey key,
    TimedSubtitle translatedSubtitle,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(<String, dynamic>{
      'stableKey': key.stableKey,
      'subtitle': translatedSubtitle.toMap(),
    });
    await prefs.setString(key.storageKey, payload);
  }
}
