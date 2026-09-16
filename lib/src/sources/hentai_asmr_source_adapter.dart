import 'package:dio/dio.dart';

import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class HentaiAsmrSourceAdapter
    implements UnifiedSourceAdapter, CatalogCountAwareSourceAdapter {
  static const String baseUrl = 'https://hentaiasmr.moe';
  static const int _sitePageSize = 15;

  final Dio _dio;
  final Map<String, int> _lastSitePageCache = <String, int>{};
  final Map<String, int> _totalCountCache = <String, int>{};

  HentaiAsmrSourceAdapter({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['User-Agent'] = 'Hiraukan/3.8 UnifiedSources'
      ..headers['Accept'] = 'text/html,application/xhtml+xml';
  }

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.hentaiAsmr;

  @override
  int? knownTotalCount(String keyword) =>
      _totalCountCache[keyword.trim().toLowerCase()];

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    final trimmedKeyword = keyword.trim();
    final cacheKey = trimmedKeyword.toLowerCase();
    final logicalPage = page < 1 ? 1 : page;
    final logicalPageSize = pageSize < 1 ? 1 : pageSize;
    final startIndex = (logicalPage - 1) * logicalPageSize;

    final cachedTotal = _totalCountCache[cacheKey];
    if (cachedTotal != null && startIndex >= cachedTotal) {
      return SourceSearchPage(
        items: const [],
        totalCount: cachedTotal,
        hasMore: false,
      );
    }

    final firstSitePage = (startIndex ~/ _sitePageSize) + 1;
    final offsetInFirstSitePage = startIndex % _sitePageSize;
    final firstHtml = await _getHtml(
      _catalogUrl(trimmedKeyword, firstSitePage),
    );
    final firstItems = _parseCatalogPage(firstHtml);

    var lastSitePage = _lastSitePageCache[cacheKey] ??
        _parseLastSitePage(firstHtml, fallback: firstSitePage);
    if (lastSitePage < firstSitePage) lastSitePage = firstSitePage;
    _lastSitePageCache[cacheKey] = lastSitePage;

    final requestedEndIndex = startIndex + logicalPageSize - 1;
    var finalSitePage = (requestedEndIndex ~/ _sitePageSize) + 1;
    if (finalSitePage > lastSitePage) finalSitePage = lastSitePage;

    final parsedPages = <int, List<SourceWorkCandidate>>{
      firstSitePage: firstItems,
    };
    final pagesToFetch = <int>{};
    for (var sitePage = firstSitePage + 1;
        sitePage <= finalSitePage;
        sitePage++) {
      pagesToFetch.add(sitePage);
    }

    // Resolve the exact catalog size once per query by reading the final site
    // page. HentaiASMR currently serves 15 works per site page while Hiraukan
    // commonly asks for 40/80 items, so one logical Hiraukan page spans several
    // website pages.
    final needsTotalCount = !_totalCountCache.containsKey(cacheKey);
    if (needsTotalCount && lastSitePage != firstSitePage) {
      pagesToFetch.add(lastSitePage);
    }

    if (pagesToFetch.isNotEmpty) {
      final pageNumbers = pagesToFetch.toList()..sort();
      final htmlPages = await Future.wait(
        pageNumbers.map(
          (sitePage) => _getHtml(_catalogUrl(trimmedKeyword, sitePage)),
        ),
      );
      for (var index = 0; index < pageNumbers.length; index++) {
        parsedPages[pageNumbers[index]] = _parseCatalogPage(htmlPages[index]);
      }
    }

    var totalCount = _totalCountCache[cacheKey];
    if (totalCount == null) {
      final lastItems = parsedPages[lastSitePage] ?? const <SourceWorkCandidate>[];
      totalCount = (lastSitePage - 1) * _sitePageSize + lastItems.length;
      _totalCountCache[cacheKey] = totalCount;
    }

    final combined = <SourceWorkCandidate>[];
    for (var sitePage = firstSitePage;
        sitePage <= finalSitePage;
        sitePage++) {
      combined.addAll(parsedPages[sitePage] ?? const <SourceWorkCandidate>[]);
    }

    final items = combined
        .skip(offsetInFirstSitePage)
        .take(logicalPageSize)
        .toList(growable: false);
    final hasMore = startIndex + items.length < totalCount;

    return SourceSearchPage(
      items: items,
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  String _catalogUrl(String keyword, int sitePage) {
    final encoded = Uri.encodeQueryComponent(keyword);
    if (keyword.isEmpty) {
      return sitePage <= 1 ? '$baseUrl/' : '$baseUrl/page/$sitePage/';
    }
    return sitePage <= 1
        ? '$baseUrl/?s=$encoded'
        : '$baseUrl/page/$sitePage/?s=$encoded';
  }

  int _parseLastSitePage(String html, {required int fallback}) {
    var lastPage = fallback;
    final pagePattern = RegExp(
      r'''/page/(\d+)(?:/|[?"'])''',
      caseSensitive: false,
    );
    for (final match in pagePattern.allMatches(html)) {
      final value = int.tryParse(match.group(1)!);
      if (value != null && value > lastPage) lastPage = value;
    }
    return lastPage;
  }

  List<SourceWorkCandidate> _parseCatalogPage(String html) {
    final base = Uri.parse(baseUrl);
    final linkPattern = RegExp(
      r'''<a\b[^>]*href=["']([^"']*((?:rj|bj|vj)\d+)\.html(?:\?[^"']*)?)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );

    final seen = <String>{};
    final items = <SourceWorkCandidate>[];
    for (final match in linkPattern.allMatches(html)) {
      final rawUrl = match.group(1)!;
      final rawId = match.group(2)!;
      final body = match.group(3)!;
      final canonical = SourceHtmlParser.extractCanonicalId(rawId) ??
          SourceHtmlParser.extractCanonicalId(body);
      final localId = canonical ?? rawId.toUpperCase();
      if (!seen.add(localId)) continue;

      final detailUrl = SourceHtmlParser.resolveUrl(rawUrl, base: base) ?? rawUrl;
      final plain = SourceHtmlParser.stripTags(body);
      var title = plain;
      if (canonical != null) {
        title = title.replaceAll(
          RegExp(RegExp.escape(canonical), caseSensitive: false),
          '',
        );
      }
      title = title
          .replaceFirst(
            RegExp(
              r'^\s*\d+\s+(?:(?:\d{1,2}:)?\d{1,2}:\d{2})\s+\d+\s+',
            ),
            '',
          )
          .trim();
      if (title.isEmpty) title = canonical ?? localId;

      final duration = SourceHtmlParser.parseDurationSeconds(plain);
      final cover = SourceHtmlParser.extractFirstImage(body, base: base);
      final ref = UnifiedSourceRef(
        source: kind,
        localId: localId,
        canonicalId: canonical,
        detailUrl: detailUrl,
        coverUrl: cover,
        title: title,
        durationSeconds: duration,
      );
      final work = Work(
        id: SourceHtmlParser.stableNegativeId('hentai:$localId'),
        title: title,
        age: 'R18',
        duration: duration,
        images: cover == null ? null : [cover],
        sourceUrl: detailUrl,
        sourceId: canonical,
      );
      items.add(SourceWorkCandidate(work: work, ref: ref));
    }
    return items;
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final base = Uri.parse(ref.detailUrl);
    final title = SourceHtmlParser.extractTitle(html) ?? ref.title ?? ref.localId;
    final canonical =
        ref.canonicalId ?? SourceHtmlParser.extractCanonicalId('$title $html');
    final cover =
        SourceHtmlParser.extractFirstImage(html, base: base) ?? ref.coverUrl;
    final audioUrls = SourceHtmlParser.extractAudioUrls(html, base: base);

    return Work(
      id: SourceHtmlParser.stableNegativeId(
        'hentai:${canonical ?? ref.localId}',
      ),
      title: title,
      age: 'R18',
      duration: ref.durationSeconds,
      images: cover == null ? null : [cover],
      sourceUrl: ref.detailUrl,
      sourceId: canonical,
      description: SourceHtmlParser.extractMetaContent(html, 'description'),
      children: audioUrls
          .asMap()
          .entries
          .map(
            (entry) => AudioFile(
              title: SourceHtmlParser.basenameFromUrl(entry.value, entry.key),
              type: 'audio',
              mediaDownloadUrl: entry.value,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final base = Uri.parse(ref.detailUrl);
    final urls = SourceHtmlParser.extractAudioUrls(html, base: base);
    return urls.asMap().entries.map((entry) {
      final url = entry.value;
      return <String, dynamic>{
        'title': SourceHtmlParser.basenameFromUrl(url, entry.key),
        'type': 'audio',
        'hash': '${kind.id}:${ref.localId}:${entry.key}',
        'mediaStreamUrl': url,
      };
    }).toList(growable: false);
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    try {
      final response = await _dio.get<String>(
        '$baseUrl/',
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
        headers: {'Referer': '$baseUrl/'},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    return response.data ?? '';
  }
}
