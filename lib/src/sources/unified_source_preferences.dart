import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/work.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class UnifiedSourcePreferences {
  static const _enabledKey = 'unified_sources_enabled_v1';
  static const _preferredKey = 'unified_source_preferred_v1';
  static const _bundleCacheKey = 'unified_source_bundle_cache_v1';
  static const _maxCachedBundles = 80;

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

  /// Persists only bundles the user actually opens/plays. This keeps fallback
  /// mirrors available after restart without turning every search result into a
  /// large permanent cache.
  static Future<void> saveBundle(UnifiedWorkBundle bundle) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decodeBundleRecords(prefs.getString(_bundleCacheKey));
    records.removeWhere((item) {
      return item['canonicalKey'] == bundle.canonicalKey ||
          item['workId'] == bundle.work.id;
    });
    records.insert(0, _bundleToJson(bundle));
    if (records.length > _maxCachedBundles) {
      records.removeRange(_maxCachedBundles, records.length);
    }
    await prefs.setString(_bundleCacheKey, jsonEncode(records));
  }

  static Future<UnifiedWorkBundle?> loadBundle(Work work) async {
    final prefs = await SharedPreferences.getInstance();
    final records = _decodeBundleRecords(prefs.getString(_bundleCacheKey));
    final canonical = SourceHtmlParser.canonicalMatchKey(
      work.sourceId ?? work.title,
    );
    final canonicalKey = canonical == null ? null : 'id:$canonical';

    for (final item in records) {
      if (item['workId'] != work.id && item['canonicalKey'] != canonicalKey) {
        continue;
      }
      final rawSources = item['sources'];
      if (rawSources is! List) continue;
      final sources = <UnifiedSourceRef>[];
      for (final raw in rawSources) {
        if (raw is! Map) continue;
        final source = _sourceById(raw['source']?.toString());
        final localId = raw['localId']?.toString();
        final detailUrl = raw['detailUrl']?.toString();
        if (source == null ||
            localId == null ||
            localId.isEmpty ||
            detailUrl == null ||
            detailUrl.isEmpty) {
          continue;
        }
        sources.add(
          UnifiedSourceRef(
            source: source,
            localId: localId,
            detailUrl: detailUrl,
            canonicalId: raw['canonicalId']?.toString(),
            coverUrl: raw['coverUrl']?.toString(),
            title: raw['title']?.toString(),
            circle: raw['circle']?.toString(),
            durationSeconds: raw['durationSeconds'] is num
                ? (raw['durationSeconds'] as num).toInt()
                : null,
          ),
        );
      }
      if (sources.isEmpty) return null;
      return UnifiedWorkBundle(
        work: work,
        canonicalKey: item['canonicalKey']?.toString() ??
            canonicalKey ??
            'work:${work.id}',
        sources: sources,
      );
    }
    return null;
  }

  static List<Map<String, dynamic>> _decodeBundleRecords(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Map<String, dynamic> _bundleToJson(UnifiedWorkBundle bundle) {
    return <String, dynamic>{
      'workId': bundle.work.id,
      'canonicalKey': bundle.canonicalKey,
      'sources': bundle.sources
          .map(
            (source) => <String, dynamic>{
              'source': source.source.id,
              'localId': source.localId,
              'canonicalId': source.canonicalId,
              'detailUrl': source.detailUrl,
              'coverUrl': source.coverUrl,
              'title': source.title,
              'circle': source.circle,
              'durationSeconds': source.durationSeconds,
            },
          )
          .toList(growable: false),
    };
  }

  static UnifiedSourceKind? _sourceById(String? id) {
    if (id == null) return null;
    for (final source in UnifiedSourceKind.values) {
      if (source.id == id) return source;
    }
    return null;
  }
}
