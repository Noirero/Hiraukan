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

    final discoveredLastSitePage =
        _parseLastSitePage(firstHtml, fallback: firstSitePage);
    int lastSitePage;
    if (logicalPage == 1) {
      // Page one contains the provider's "last" navigation link. Refresh it
      // instead of keeping an old session count forever, because HentaiASMR's
      // archive grows independently from Hiraukan releases.
      lastSitePage = discoveredLastSitePage;
      _lastSitePageCache[cacheKey] = lastSitePage;
      _totalCountCache.remove(cacheKey);
    } else {
      lastSitePage =
          _lastSitePageCache[cacheKey] ?? discoveredLastSitePage;
      if (lastSitePage < firstSitePage) lastSitePage = firstSitePage;
      _lastSitePageCache[cacheKey] = lastSitePage;
    }

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

    // Resolve the provider-authoritative archive size by also reading its last
    // page. HentaiASMR serves 15 entries per catalog page. The final page can
    // contain fewer entries, so reading it prevents the Hiraukan pager from
    // truncating the archive.
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
      final lastItems =
          parsedPages[lastSitePage] ?? const <SourceWorkCandidate>[];
      // If the provider changes the markup on an old final page, prefer a
      // conservative upper bound over hiding that page completely. Once the
      // page is parseable again the exact count replaces this value.
      final lastPageCount =
          lastItems.isEmpty ? _sitePageSize : lastItems.length;
      totalCount =
          ((lastSitePage - 1) * _sitePageSize) + lastPageCount;
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
    final hasMore = finalSitePage < lastSitePage ||
        startIndex + items.length < totalCount;

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
      r'''/page/(\d+)(?=[/?#"'<\s]|$)''',
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
    final anchorPattern = RegExp(
      r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );

    // HentaiASMR has used more than one permalink shape over its lifetime:
    // current entries commonly use /RJxxxx.html while older archive entries
    // can use /RJxxxx/. Parsing every work anchor by canonical ID keeps both
    // generations visible instead of silently dropping the older archive.
    final entries = <String, _CatalogEntryBuilder>{};
    final order = <String>[];
    for (final match in anchorPattern.allMatches(html)) {
      final rawUrl = SourceHtmlParser.decodeEntities(match.group(1)!.trim());
      final body = match.group(2)!;
      final canonical = SourceHtmlParser.extractCanonicalId(rawUrl) ??
          SourceHtmlParser.extractCanonicalId(body);
      if (canonical == null ||
          !_looksLikeWorkDetailUrl(rawUrl, canonical, base: base)) {
        continue;
      }

      final localId = canonical.toUpperCase();
      final detailUrl =
          SourceHtmlParser.resolveUrl(rawUrl, base: base) ?? rawUrl;
      final plain = SourceHtmlParser.stripTags(body);
      final candidateTitle = _cleanCatalogTitle(plain, canonical);
      final duration = SourceHtmlParser.parseDurationSeconds(plain);
      final cover = SourceHtmlParser.extractFirstImage(body, base: base);

      final existing = entries[localId];
      if (existing == null) {
        order.add(localId);
        entries[localId] = _CatalogEntryBuilder(
          localId: localId,
          canonicalId: canonical,
          detailUrl: detailUrl,
          title: candidateTitle,
          durationSeconds: duration,
          coverUrl: cover,
        );
      } else {
        existing.absorb(
          title: candidateTitle,
          durationSeconds: duration,
          coverUrl: cover,
        );
      }
    }

    return order.map((localId) {
      final entry = entries[localId]!;
      final title = entry.title.isEmpty ? entry.canonicalId : entry.title;
      final ref = UnifiedSourceRef(
        source: kind,
        localId: entry.localId,
        canonicalId: entry.canonicalId,
        detailUrl: entry.detailUrl,
        coverUrl: entry.coverUrl,
        title: title,
        durationSeconds: entry.durationSeconds,
      );
      final work = Work(
        id: SourceHtmlParser.stableNegativeId('hentai:${entry.localId}'),
        title: title,
        age: 'R18',
        duration: entry.durationSeconds,
        images: entry.coverUrl == null ? null : [entry.coverUrl!],
        sourceUrl: entry.detailUrl,
        sourceId: entry.canonicalId,
      );
      return SourceWorkCandidate(work: work, ref: ref);
    }).toList(growable: false);
  }

  bool _looksLikeWorkDetailUrl(
    String rawUrl,
    String canonical, {
    required Uri base,
  }) {
    final resolved = SourceHtmlParser.resolveUrl(rawUrl, base: base);
    final uri = Uri.tryParse(resolved ?? rawUrl);
    if (uri == null) return false;

    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    if (host.isNotEmpty && host != 'hentaiasmr.moe') return false;

    // Requiring the ID in the path rejects search links such as /?s=RJxxxx
    // while accepting both /RJxxxx.html and the legacy /RJxxxx/ permalink.
    return uri.path.toUpperCase().contains(canonical.toUpperCase());
  }

  String _cleanCatalogTitle(String plain, String canonical) {
    var title = plain;
    title = title.replaceAll(
      RegExp(RegExp.escape(canonical), caseSensitive: false),
      ' ',
    );
    title = title
        .replaceFirst(
          RegExp(
            r'^\s*\d+\s+(?:(?:\d{1,2}:)?\d{1,2}:\d{2})\s+\d+\s+',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return title;
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final base = Uri.parse(ref.detailUrl);
    final rawTitle =
        SourceHtmlParser.extractTitle(html) ?? ref.title ?? ref.localId;
    final canonical =
        ref.canonicalId ?? SourceHtmlParser.extractCanonicalId('$rawTitle $html');
    final title = _cleanDetailTitle(rawTitle, canonical);
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

  String _cleanDetailTitle(String rawTitle, String? canonical) {
    var title = SourceHtmlParser.stripTags(rawTitle).trim();
    if (canonical != null && canonical.isNotEmpty) {
      final escaped = RegExp.escape(canonical);
      title = title
          .replaceFirst(
            RegExp(
              '^\\s*[\\[（(]?\\s*$escaped\\s*[\\]）)]?\\s*[-:：|]?\\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }

    // WordPress page titles may append the provider name. It is useful as a
    // browser title but noisy in Hiraukan where the source is already shown.
    title = title
        .replaceFirst(
          RegExp(r'\s*[-|｜]\s*HentaiASMR.*$', caseSensitive: false),
          '',
        )
        .trim();

    return title.isEmpty ? (canonical ?? refallback(rawTitle)) : title;
  }

  String refallback(String value) {
    final cleaned = SourceHtmlParser.stripTags(value).trim();
    return cleaned.isEmpty ? 'HentaiASMR' : cleaned;
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

class _CatalogEntryBuilder {
  _CatalogEntryBuilder({
    required this.localId,
    required this.canonicalId,
    required this.detailUrl,
    required this.title,
    required this.durationSeconds,
    required this.coverUrl,
  });

  final String localId;
  final String canonicalId;
  final String detailUrl;
  String title;
  int? durationSeconds;
  String? coverUrl;

  void absorb({
    required String title,
    required int? durationSeconds,
    required String? coverUrl,
  }) {
    if (title.isNotEmpty && title.length > this.title.length) {
      this.title = title;
    }
    this.durationSeconds ??= durationSeconds;
    this.coverUrl ??= coverUrl;
  }
}
