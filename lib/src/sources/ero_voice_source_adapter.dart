import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class EroVoiceSourceAdapter implements UnifiedSourceAdapter {
  static const List<String> _baseCandidates = [
    'https://e.erovoice.us',
    'http://e.erovoice.us',
  ];

  final Dio _dio;
  final Map<String, String> _entryContentByUrl = <String, String>{};
  String? _healthyBase;

  EroVoiceSourceAdapter({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 18)
      ..headers['User-Agent'] = 'KikoFlu/3.8 UnifiedSources'
      ..headers['Accept'] = 'application/json,text/html,application/xhtml+xml';
  }

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.eroVoice;

  @override
  SourceCapabilities get capabilities => kind.capabilities;

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    final startIndex = ((page - 1) * pageSize) + 1;
    final encoded = Uri.encodeQueryComponent(keyword.trim());
    Object? decoded;
    String? usedBase;

    for (final base in _orderedBases) {
      try {
        final url =
            '$base/feeds/posts/default?alt=json&q=$encoded&start-index=$startIndex&max-results=$pageSize';
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        decoded = jsonDecode(response.data ?? '{}');
        usedBase = base;
        _healthyBase = base;
        break;
      } catch (_) {
        continue;
      }
    }

    if (decoded is! Map) {
      throw StateError('EroVoice feed is currently unavailable');
    }

    final feed = decoded['feed'];
    if (feed is! Map) {
      return const SourceSearchPage(
        items: [],
        totalCount: 0,
        hasMore: false,
      );
    }

    final entries = (feed['entry'] as List?) ?? const [];
    final totalRaw = feed[r'openSearch$totalResults'];
    final totalText = totalRaw is Map ? totalRaw[r'$t']?.toString() : null;
    final totalCount = int.tryParse(totalText ?? '') ?? entries.length;
    final items = <SourceWorkCandidate>[];

    for (final raw in entries) {
      if (raw is! Map) continue;
      final titleMap = raw['title'];
      final title = titleMap is Map
          ? SourceHtmlParser.stripTags(titleMap[r'$t']?.toString() ?? '')
          : '';
      final contentMap = raw['content'] ?? raw['summary'];
      final content =
          contentMap is Map ? contentMap[r'$t']?.toString() ?? '' : '';
      final canonical =
          SourceHtmlParser.extractCanonicalId('$title $content');
      final links = (raw['link'] as List?) ?? const [];
      String? detailUrl;
      for (final link in links) {
        if (link is Map && link['rel'] == 'alternate') {
          detailUrl = link['href']?.toString();
          if (detailUrl != null) break;
        }
      }
      detailUrl ??= raw['id'] is Map
          ? (raw['id'] as Map)[r'$t']?.toString()
          : null;
      if (detailUrl == null || detailUrl.isEmpty) continue;

      if (content.isNotEmpty) {
        _entryContentByUrl[detailUrl] = content;
      }

      final localId = canonical ?? detailUrl;
      final mediaThumbnail = raw[r'media$thumbnail'];
      final thumbnail = mediaThumbnail is Map
          ? mediaThumbnail['url']?.toString()
          : null;
      final cover = SourceHtmlParser.resolveUrl(
            thumbnail,
            base: Uri.tryParse(usedBase ?? _baseCandidates.first),
          ) ??
          SourceHtmlParser.extractFirstImage(
            content,
            base: Uri.tryParse(usedBase ?? _baseCandidates.first),
          );
      final circle = _extractMetadata(content, 'Circle');
      final release = _extractMetadata(content, 'Release');
      final voiceActor = _extractMetadata(content, 'Voice Actor');
      final effectiveTitle = title.isEmpty ? canonical ?? 'EroVoice' : title;
      final ref = UnifiedSourceRef(
        source: kind,
        localId: localId,
        canonicalId: canonical,
        detailUrl: detailUrl,
        coverUrl: cover,
        title: effectiveTitle,
        circle: circle,
      );
      final work = Work(
        id: SourceHtmlParser.stableNegativeId('erovoice:$localId'),
        title: effectiveTitle,
        name: circle,
        release: release,
        vas: voiceActor == null
            ? null
            : [
                Va(
                  id: 'erovoice:${SourceHtmlParser.stableNegativeId(voiceActor)}',
                  name: voiceActor,
                ),
              ],
        images: cover == null ? null : [cover],
        sourceUrl: detailUrl,
        sourceId: canonical,
      );
      items.add(SourceWorkCandidate(work: work, ref: ref));
    }

    return SourceSearchPage(
      items: items,
      totalCount: totalCount,
      hasMore: startIndex - 1 + entries.length < totalCount,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final content = await _loadPageOrCachedContent(ref);
    final title =
        SourceHtmlParser.extractTitle(content) ?? ref.title ?? ref.localId;
    final canonical = ref.canonicalId ??
        SourceHtmlParser.extractCanonicalId('$title $content');
    final cover = SourceHtmlParser.extractFirstImage(
          content,
          base: Uri.tryParse(ref.detailUrl),
        ) ??
        ref.coverUrl;
    final circle = _extractMetadata(content, 'Circle') ?? ref.circle;
    final release = _extractMetadata(content, 'Release');
    final voiceActor = _extractMetadata(content, 'Voice Actor');
    final audioUrls = SourceHtmlParser.extractAudioUrls(
      content,
      base: Uri.tryParse(ref.detailUrl),
    );

    return Work(
      id: SourceHtmlParser.stableNegativeId(
        'erovoice:${canonical ?? ref.localId}',
      ),
      title: title,
      name: circle,
      release: release,
      vas: voiceActor == null
          ? null
          : [
              Va(
                id: 'erovoice:${SourceHtmlParser.stableNegativeId(voiceActor)}',
                name: voiceActor,
              ),
            ],
      images: cover == null ? null : [cover],
      sourceUrl: ref.detailUrl,
      sourceId: canonical,
      description: SourceHtmlParser.extractMetaContent(content, 'description'),
      children: audioUrls
          .asMap()
          .entries
          .map(
            (entry) => AudioFile(
              title: SourceHtmlParser.basenameFromUrl(
                entry.value,
                entry.key,
              ),
              type: 'audio',
              mediaDownloadUrl: entry.value,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    final content = await _loadPageOrCachedContent(ref);
    final urls = SourceHtmlParser.extractAudioUrls(
      content,
      base: Uri.tryParse(ref.detailUrl),
    );
    return urls.asMap().entries.map((entry) {
      return <String, dynamic>{
        'title': SourceHtmlParser.basenameFromUrl(entry.value, entry.key),
        'type': 'audio',
        'hash': '${kind.id}:${ref.localId}:${entry.key}',
        'mediaStreamUrl': entry.value,
      };
    }).toList(growable: false);
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    for (final base in _orderedBases) {
      try {
        final response = await _dio.get<String>(
          '$base/feeds/posts/default?alt=json&max-results=1',
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 400) {
          final decoded = jsonDecode(response.data ?? '{}');
          if (decoded is Map && decoded['feed'] is Map) {
            _healthyBase = base;
            return UnifiedSourceHealth.healthy;
          }
          return UnifiedSourceHealth.degraded;
        }
        if (status > 0) return UnifiedSourceHealth.degraded;
      } catch (_) {
        continue;
      }
    }
    return UnifiedSourceHealth.broken;
  }

  Iterable<String> get _orderedBases sync* {
    final healthy = _healthyBase;
    if (healthy != null) yield healthy;
    for (final base in _baseCandidates) {
      if (base != healthy) yield base;
    }
  }

  Future<String> _loadPageOrCachedContent(UnifiedSourceRef ref) async {
    try {
      return await _getHtml(ref.detailUrl);
    } catch (_) {
      final cached = _entryContentByUrl[ref.detailUrl];
      if (cached != null && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  String? _extractMetadata(String html, String label) {
    final match = RegExp(
      '${RegExp.escape(label)}\\s*:\\s*([^<&]+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;
    final value = SourceHtmlParser.decodeEntities(match.group(1)!)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value.isEmpty ? null : value;
  }

  Future<String> _getHtml(String url) async {
    final candidates = <String>[url];
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host == 'e.erovoice.us') {
      final alternateScheme = uri.scheme == 'http' ? 'https' : 'http';
      candidates.add(uri.replace(scheme: alternateScheme).toString());
    }

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final response = await _dio.get<String>(
          candidate,
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        if (Uri.tryParse(candidate)?.host == 'e.erovoice.us') {
          _healthyBase = '${Uri.parse(candidate).scheme}://e.erovoice.us';
        }
        return response.data ?? '';
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('EroVoice page unavailable: $lastError');
  }
}
