import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

typedef HtmlCatalogUrlBuilder = String Function(String keyword, int page);
typedef HtmlDetailUrlMatcher = bool Function(Uri uri);
typedef ExtraPlayableUrlResolver = Future<List<String>> Function(
  String html,
  Uri pageUri,
  String? canonicalId,
  Dio dio,
);

class HtmlAudioSiteSourceAdapter implements UnifiedSourceAdapter {
  @override
  final UnifiedSourceKind kind;

  final String baseUrl;
  final String cacheNamespace;
  final HtmlCatalogUrlBuilder catalogUrlBuilder;
  final HtmlDetailUrlMatcher detailUrlMatcher;
  final bool mediaEnabled;
  final ExtraPlayableUrlResolver? extraPlayableUrlResolver;
  final Dio _dio;

  HtmlAudioSiteSourceAdapter({
    required this.kind,
    required this.baseUrl,
    required this.cacheNamespace,
    required this.catalogUrlBuilder,
    required this.detailUrlMatcher,
    this.mediaEnabled = true,
    this.extraPlayableUrlResolver,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 22)
      ..headers['User-Agent'] = 'Hiraukan/3.8 UnifiedSources'
      ..headers['Accept'] = 'text/html,application/xhtml+xml,*/*;q=0.8';
  }

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    final logicalPage = page < 1 ? 1 : page;
    final html = await _getHtml(catalogUrlBuilder(keyword.trim(), logicalPage));
    final parsed = _parseCatalogPage(html);
    final items = parsed.length > pageSize
        ? parsed.take(pageSize).toList(growable: false)
        : parsed;
    final hasMore = _hasNextPage(html, logicalPage);
    final totalCount =
        ((logicalPage - 1) * pageSize) + items.length + (hasMore ? pageSize : 0);

    return SourceSearchPage(
      items: items,
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  List<SourceWorkCandidate> _parseCatalogPage(String html) {
    final root = Uri.parse(baseUrl);
    final anchors = RegExp(
      r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    final results = <SourceWorkCandidate>[];
    final seen = <String>{};

    for (final match in anchors.allMatches(html)) {
      final resolved = SourceHtmlParser.resolveUrl(match.group(1), base: root);
      final uri = resolved == null ? null : Uri.tryParse(resolved);
      if (uri == null || !detailUrlMatcher(uri) || !seen.add(resolved!)) {
        continue;
      }

      final start = math.max(0, match.start - 900);
      final end = math.min(html.length, match.end + 1300);
      final context = html.substring(start, end);
      final canonical = SourceHtmlParser.extractCanonicalId(
        resolved + ' ' + context,
      );
      final localId = canonical ?? uri.path;
      final title = _catalogTitle(
        match.group(2) ?? '',
        context,
        canonical,
      );
      final cover = SourceHtmlParser.extractFirstImage(
        match.group(2) ?? '',
        base: uri,
      ) ??
          SourceHtmlParser.extractFirstImage(context, base: uri);
      final duration = SourceHtmlParser.parseDurationSeconds(
        SourceHtmlParser.stripTags(context),
      );

      final ref = UnifiedSourceRef(
        source: kind,
        localId: localId,
        canonicalId: canonical,
        detailUrl: resolved,
        coverUrl: cover,
        title: title,
        durationSeconds: duration,
      );
      final work = Work(
        id: SourceHtmlParser.stableNegativeId(cacheNamespace + ':' + localId),
        title: title,
        age: 'R18',
        duration: duration,
        images: cover == null ? null : [cover],
        sourceUrl: resolved,
        sourceId: canonical,
      );
      results.add(SourceWorkCandidate(work: work, ref: ref));
    }

    return results;
  }

  String _catalogTitle(String anchorBody, String context, String? canonical) {
    var value = SourceHtmlParser.stripTags(anchorBody);
    if (_looksGenericTitle(value)) {
      value = '';
    }
    if (value.isEmpty) {
      final headings = RegExp(
        r'<h[1-4]\b[^>]*>(.*?)</h[1-4]>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(context);
      for (final heading in headings) {
        final candidate = SourceHtmlParser.stripTags(heading.group(1) ?? '');
        if (!_looksGenericTitle(candidate) && candidate.length >= 3) {
          value = candidate;
          break;
        }
      }
    }

    if (canonical != null && value.isNotEmpty) {
      value = value
          .replaceAll(
            RegExp(RegExp.escape(canonical), caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return value.isEmpty ? (canonical ?? kind.label) : value;
  }

  bool _looksGenericTitle(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'read more' ||
        normalized == 'download' ||
        normalized == 'play' ||
        normalized == 'open';
  }

  bool _hasNextPage(String html, int currentPage) {
    final next = currentPage + 1;
    final lower = html.toLowerCase();
    return lower.contains('/page/' + next.toString() + '/') ||
        lower.contains('paged=' + next.toString()) ||
        lower.contains('page=' + next.toString()) ||
        RegExp(
          r'''rel=["']next["']''',
          caseSensitive: false,
        ).hasMatch(html);
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final rawTitle =
        SourceHtmlParser.extractTitle(html) ?? ref.title ?? ref.localId;
    final canonical = ref.canonicalId ??
        SourceHtmlParser.extractCanonicalId(rawTitle + ' ' + html);
    final title = _cleanDetailTitle(rawTitle, canonical);
    final cover =
        SourceHtmlParser.extractFirstImage(html, base: pageUri) ?? ref.coverUrl;
    final playable = mediaEnabled
        ? await _resolvePlayableUrls(html, pageUri, canonical)
        : const <String>[];

    return Work(
      id: SourceHtmlParser.stableNegativeId(
        cacheNamespace + ':' + (canonical ?? ref.localId),
      ),
      title: title,
      age: 'R18',
      duration: ref.durationSeconds,
      images: cover == null ? null : [cover],
      sourceUrl: ref.detailUrl,
      sourceId: canonical,
      description: SourceHtmlParser.extractMetaContent(html, 'description'),
      children: playable
          .asMap()
          .entries
          .map(
            (entry) => AudioFile(
              title: _mediaTitle(entry.value, entry.key),
              type: 'audio',
              mediaDownloadUrl: entry.value,
            ),
          )
          .toList(growable: false),
    );
  }

  String _cleanDetailTitle(String rawTitle, String? canonical) {
    var title = SourceHtmlParser.stripTags(rawTitle)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (canonical != null) {
      title = title
          .replaceAll(
            RegExp(RegExp.escape(canonical), caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return title.isEmpty ? (canonical ?? kind.label) : title;
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    if (!mediaEnabled) return const [];
    final html = await _getHtml(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final canonical =
        ref.canonicalId ?? SourceHtmlParser.extractCanonicalId(html);
    final urls = await _resolvePlayableUrls(html, pageUri, canonical);
    return urls.asMap().entries.map((entry) {
      return <String, dynamic>{
        'title': _mediaTitle(entry.value, entry.key),
        'type': 'audio',
        'hash': kind.id + ':' + ref.localId + ':' + entry.key.toString(),
        'mediaStreamUrl': entry.value,
      };
    }).toList(growable: false);
  }

  Future<List<String>> _resolvePlayableUrls(
    String html,
    Uri pageUri,
    String? canonical,
  ) async {
    final result = <String>{
      ...SourceHtmlParser.extractPlayableUrls(html, base: pageUri),
    };
    final resolver = extraPlayableUrlResolver;
    if (resolver != null) {
      result.addAll(await resolver(html, pageUri, canonical, _dio));
    }
    return result.toList(growable: false);
  }

  String _mediaTitle(String url, int index) {
    final lower = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (lower.endsWith('.m3u8')) {
      return 'Stream ' + (index + 1).toString() + '.m3u8';
    }
    return SourceHtmlParser.basenameFromUrl(url, index);
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    try {
      final response = await _dio.get<String>(
        baseUrl + '/',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final status = response.statusCode ?? 0;
      return status >= 200 && status < 400
          ? UnifiedSourceHealth.healthy
          : UnifiedSourceHealth.degraded;
    } catch (_) {
      return UnifiedSourceHealth.broken;
    }
  }

  Future<String> _getHtml(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': baseUrl + '/'},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    return response.data ?? '';
  }
}
