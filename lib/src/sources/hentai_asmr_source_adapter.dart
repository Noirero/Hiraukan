import 'package:dio/dio.dart';

import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class HentaiAsmrSourceAdapter implements UnifiedSourceAdapter {
  static const String baseUrl = 'https://hentaiasmr.moe';

  final Dio _dio;

  HentaiAsmrSourceAdapter({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['User-Agent'] = 'KikoFlu/3.8 UnifiedSources'
      ..headers['Accept'] = 'text/html,application/xhtml+xml';
  }

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.hentaiAsmr;

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    final encoded = Uri.encodeQueryComponent(keyword.trim());
    final url = page <= 1
        ? '$baseUrl/?s=$encoded'
        : '$baseUrl/page/$page/?s=$encoded';
    final html = await _getHtml(url);
    final base = Uri.parse(baseUrl);

    final linkPattern = RegExp(
      r'<a\b[^>]*href=["\']([^"\']*/(rj\d+)\.html(?:\?[^"\']*)?)["\'][^>]*>(.*?)</a>',
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
          .replaceFirst(RegExp(r'^\s*\d+\s+(?:(?:\d{1,2}:)?\d{1,2}:\d{2})\s+\d+\s+'), '')
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
        duration: duration,
        images: cover == null ? null : [cover],
        sourceUrl: detailUrl,
        sourceId: canonical,
      );
      items.add(SourceWorkCandidate(work: work, ref: ref));
    }

    final nextPageHint = RegExp(
      page <= 1 ? r'/page/2/' : '/page/${page + 1}/',
      caseSensitive: false,
    ).hasMatch(html);
    final hasMore = nextPageHint || items.length >= pageSize;
    final estimatedTotal = (page - 1) * pageSize + items.length +
        (hasMore ? pageSize : 0);

    return SourceSearchPage(
      items: items,
      totalCount: estimatedTotal,
      hasMore: hasMore,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final base = Uri.parse(ref.detailUrl);
    final title = SourceHtmlParser.extractTitle(html) ?? ref.title ?? ref.localId;
    final canonical = ref.canonicalId ?? SourceHtmlParser.extractCanonicalId('$title $html');
    final cover = SourceHtmlParser.extractFirstImage(html, base: base) ?? ref.coverUrl;
    final audioUrls = SourceHtmlParser.extractAudioUrls(html, base: base);

    return Work(
      id: SourceHtmlParser.stableNegativeId('hentai:${canonical ?? ref.localId}'),
      title: title,
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
        headers: const {'Referer': '$baseUrl/'},
        validateStatus: (status) => status != null && status >= 200 && status < 400,
      ),
    );
    return response.data ?? '';
  }
}
