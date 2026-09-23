import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/work.dart';
import 'html_audio_site_source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class Asmr18Chapter {
  final String id;
  final String title;
  final int startSeconds;
  final int? endSeconds;
  final int? durationSeconds;

  const Asmr18Chapter({
    required this.id,
    required this.title,
    required this.startSeconds,
    this.endSeconds,
    this.durationSeconds,
  });
}

class Asmr18PageParser {
  const Asmr18PageParser._();

  static String? canonicalId(String html) =>
      SourceHtmlParser.extractCanonicalId(html);

  static String title(String html, {String? fallback, String? canonical}) {
    var value = SourceHtmlParser.extractTitle(html) ?? fallback ?? '';
    value = SourceHtmlParser.stripTags(value)
        .replaceFirst(
          RegExp(
            r'\s*[\-–—|]\s*(?:男子向け|乙女向け|全年齢向け)?\s*'
            r'[\-–—|]?\s*同人ボイス\s+ASMR\+18\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    if (canonical != null && canonical.isNotEmpty) {
      value = value
          .replaceAll(
            RegExp(RegExp.escape(canonical), caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
    return value.isEmpty ? (canonical ?? fallback ?? '') : value;
  }

  static String? releaseDate(String html, {String? canonical}) {
    final block = _metadataBlock(html, canonical: canonical);
    final match = RegExp(r'(20\d{2})年\s*(\d{1,2})月\s*(\d{1,2})日')
        .firstMatch(SourceHtmlParser.stripTags(block));
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static List<String> voiceActors(String html, {String? canonical}) {
    final block = _metadataBlock(html, canonical: canonical);
    return _linksAfterLabel(
      block,
      '声優',
      stopLabels: const ['サークル', 'シナリオ', 'イラスト', '音楽', 'ジャンル'],
    );
  }

  static String? circle(String html, {String? canonical}) {
    final block = _metadataBlock(html, canonical: canonical);
    final values = _linksAfterLabel(
      block,
      'サークル',
      stopLabels: const ['シナリオ', 'イラスト', '音楽', 'ジャンル'],
    );
    return values.isEmpty ? null : values.first;
  }

  static List<String> genres(String html, {String? canonical}) {
    final block = _metadataBlock(html, canonical: canonical);
    return _linksAfterLabel(
      block,
      'ジャンル',
      stopLabels: const ['プレイリスト', 'Comments', 'コメント', 'Related', '関連'],
    );
  }

  static List<Asmr18Chapter> chapters(String html) {
    final raw = <({int start, String title, int order})>[];
    final seenStarts = <int>{};
    var order = 0;

    final anchors = RegExp(
      r'''<a\b[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in anchors.allMatches(html)) {
      final text = SourceHtmlParser.stripTags(match.group(1) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final time = RegExp(r'(\d{1,2}:\d{2}:\d{2})\s*$').firstMatch(text);
      if (time == null) continue;
      final start = _timestampSeconds(time.group(1)!);
      if (start == null) continue;
      var chapterTitle = text.substring(0, time.start).trim();
      if (chapterTitle.isEmpty) chapterTitle = 'Track ${raw.length + 1}';
      if (!_looksLikeChapterTitle(chapterTitle)) continue;
      if (!seenStarts.add(start)) continue;
      raw.add((start: start, title: chapterTitle, order: order++));
    }

    raw.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.order.compareTo(b.order);
    });
    final declaredDurations = _declaredTrackDurations(html);
    final result = <Asmr18Chapter>[];

    for (var index = 0; index < raw.length; index++) {
      final current = raw[index];
      final declared = declaredDurations[index + 1];
      final nextStart = index + 1 < raw.length ? raw[index + 1].start : null;
      final end = nextStart ??
          (declared == null ? null : current.start + declared);
      final duration = end == null ? declared : end - current.start;
      result.add(
        Asmr18Chapter(
          id: 'chapter-${index + 1}',
          title: current.title,
          startSeconds: current.start,
          endSeconds: end,
          durationSeconds: duration,
        ),
      );
    }
    return result;
  }

  static bool _looksLikeChapterTitle(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty || normalized.length > 220) return false;

    final lower = normalized.toLowerCase();
    const scriptSignals = <String>[
      'string.fromcharcode',
      'tostring(36)',
      'function(',
      '=>',
      'document.',
      'window.',
      'eval(',
      'replace(/',
    ];
    if (scriptSignals.any(lower.contains)) return false;

    // A real chapter title may contain punctuation, but dense JavaScript-like
    // punctuation around a timestamp is a strong signal that an ad/player
    // script leaked into the anchor scan.
    final scriptPunctuation =
        RegExp(r'[{};=]').allMatches(normalized).length;
    if (scriptPunctuation >= 4) return false;

    return true;
  }

  static int? totalDurationSeconds(String html) {
    final chapters = Asmr18PageParser.chapters(html);
    if (chapters.isEmpty) return null;
    final last = chapters.last;
    return last.endSeconds;
  }

  static List<String> playableCandidates(
    String html, {
    required Uri pageUri,
  }) {
    final result = <String>{
      ...SourceHtmlParser.extractPlayableUrls(html, base: pageUri),
    };
    final unpacked = unpackPlayerScripts(html);
    for (final script in unpacked) {
      result.addAll(SourceHtmlParser.extractPlayableUrls(script, base: pageUri));
    }
    return result.toList(growable: false);
  }

  static List<String> unpackPlayerScripts(String html) {
    final normalized = html.replaceAll(r'\/', '/');
    final packed = RegExp(
      r'''eval\(function\(p,a,c,k,e,d\)\{.*?\}\((.*?)\)\)''',
      caseSensitive: false,
      dotAll: true,
    );
    final result = <String>[];
    for (final match in packed.allMatches(normalized)) {
      final args = match.group(1) ?? '';
      final wordsMatch = RegExp(
        r'''['"]([^'"]+)['"]\.split\(['"]\|['"]\)''',
      ).firstMatch(args);
      final codeMatch = RegExp(r'''^\s*['"]([^'"]*)['"]''').firstMatch(args);
      if (wordsMatch == null || codeMatch == null) continue;

      final words = wordsMatch.group(1)!.split('|');
      var code = codeMatch.group(1)!;
      code = code.replaceAllMapped(RegExp(r'\b([0-9a-z]+)\b'), (tokenMatch) {
        final token = tokenMatch.group(1)!;
        final index = int.tryParse(token, radix: 36);
        if (index == null || index < 0 || index >= words.length) return token;
        final replacement = words[index];
        return replacement.isEmpty ? token : replacement;
      });
      result.add(code);
    }
    return result;
  }

  static Map<int, int> _declaredTrackDurations(String html) {
    final text = _plainText(html);
    final result = <int, int>{};
    final matches = RegExp(
      r'Track\s*(\d+)\b[^\n\r]{0,250}?'
      r'\((\d{1,2}:\d{2}(?::\d{2})?)\)',
      caseSensitive: false,
    ).allMatches(text);
    for (final match in matches) {
      final trackNumber = int.tryParse(match.group(1)!);
      final duration = _timestampSeconds(match.group(2)!);
      if (trackNumber != null && duration != null && duration > 0) {
        result.putIfAbsent(trackNumber, () => duration);
      }
    }
    return result;
  }

  static String _metadataBlock(String html, {String? canonical}) {
    var start = 0;
    if (canonical != null && canonical.isNotEmpty) {
      final found = html.indexOf(canonical);
      if (found >= 0) start = math.max(0, found - 3000);
    } else {
      final heading = RegExp(r'<h1\b', caseSensitive: false).firstMatch(html);
      if (heading != null) start = heading.start;
    }
    var end = math.min(html.length, start + 10000);
    for (final marker in ['Comments', 'コメント', 'Related', '関連']) {
      final index = html.indexOf(marker, start);
      if (index >= 0 && index < end) end = index;
    }
    return html.substring(start, end);
  }

  static List<String> _linksAfterLabel(
    String block,
    String label, {
    required List<String> stopLabels,
  }) {
    final labelIndex = block.indexOf(label);
    if (labelIndex < 0) return const [];
    var end = math.min(block.length, labelIndex + 2200);
    for (final stop in stopLabels) {
      final index = block.indexOf(stop, labelIndex + label.length);
      if (index >= 0 && index < end) end = index;
    }

    final section = block.substring(labelIndex + label.length, end);
    final values = <String>{};
    final anchors = RegExp(
      r'''<a\b[^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in anchors.allMatches(section)) {
      final value = SourceHtmlParser.stripTags(match.group(1) ?? '').trim();
      if (value.isNotEmpty) values.add(value);
    }
    return values.toList(growable: false);
  }

  static String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</(?:p|div|li|tr|td|th|h[1-6]|section|article)>',
            caseSensitive: false,
          ),
          '\n',
        )
        .split('\n')
        .map(SourceHtmlParser.stripTags)
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  static int? _timestampSeconds(String value) {
    final parts = value.split(':');
    if (parts.length != 2 && parts.length != 3) return null;
    final seconds = int.tryParse(parts.last);
    final minutes = int.tryParse(parts[parts.length - 2]);
    final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
    if (seconds == null || minutes == null || hours == null) return null;
    if (seconds > 59 || minutes > 59 || hours < 0) return null;
    return hours * 3600 + minutes * 60 + seconds;
  }
}

enum Asmr18CatalogCategory {
  all('all', 'Semua', null),
  boys('boys', 'Boys', 'boys'),
  girls('girls', 'Girls', 'girls'),
  allAges('allages', 'All Ages', 'allages');

  const Asmr18CatalogCategory(this.id, this.label, this.path);

  final String id;
  final String label;
  final String? path;
}

class Asmr18SourceAdapter extends HtmlAudioSiteSourceAdapter {
  static const String baseUrl = 'https://asmr18.fans';
  static const String _userAgent = 'Hiraukan/3.8 UnifiedSources';

  final Dio _client;

  factory Asmr18SourceAdapter({Dio? dio}) {
    final client = dio ?? Dio();
    return Asmr18SourceAdapter._(client);
  }

  Asmr18SourceAdapter._(Dio client)
      : _client = client,
        super(
          kind: UnifiedSourceKind.asmr18,
          baseUrl: baseUrl,
          cacheNamespace: 'asmr18',
          catalogUrlBuilder: _catalogUrl,
          detailUrlMatcher: _isDetailUrl,
          dio: client,
        );

  static const int _providerPageSize = 24;

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) {
    return searchWithCategory(
      keyword: keyword,
      page: page,
      pageSize: pageSize,
      category: Asmr18CatalogCategory.all,
    );
  }

  Future<SourceSearchPage> searchWithCategory({
    required String keyword,
    required int page,
    required int pageSize,
    required Asmr18CatalogCategory category,
  }) async {
    final logicalPage = page < 1 ? 1 : page;
    final logicalPageSize = pageSize < 1 ? 1 : pageSize;
    final categories = category.path == null
        ? const <String>['boys', 'girls', 'allages']
        : <String>[category.path!];

    final requiredItems = logicalPage * logicalPageSize + 1;
    final estimatedPerProviderPage =
        _providerPageSize * categories.length;
    final providerPagesNeeded =
        (requiredItems / estimatedPerProviderPage).ceil().clamp(1, 200);

    final requests = <Future<SourceSearchPage?>>[];
    for (var providerPage = 1;
        providerPage <= providerPagesNeeded;
        providerPage++) {
      for (final categoryPath in categories) {
        requests.add(
          _searchCategoryPage(
            category: categoryPath,
            keyword: keyword,
            page: providerPage,
          ),
        );
      }
    }

    final pages = await Future.wait(requests);
    final available = pages.whereType<SourceSearchPage>().toList();
    if (available.isEmpty) {
      throw StateError('ASMR+18 catalog categories are unavailable');
    }

    final merged = <SourceWorkCandidate>[];
    final seen = <String>{};
    for (final sourcePage in available) {
      for (final candidate in sourcePage.items) {
        final key = candidate.ref.canonicalId?.trim().toUpperCase() ??
            candidate.ref.detailUrl.toLowerCase();
        if (seen.add(key)) merged.add(candidate);
      }
    }

    final start = (logicalPage - 1) * logicalPageSize;
    final selected = start >= merged.length
        ? const <SourceWorkCandidate>[]
        : merged.skip(start).take(logicalPageSize).toList(growable: false);
    final providerHasMore = available.any((sourcePage) => sourcePage.hasMore);
    final bufferedHasMore = start + selected.length < merged.length;
    final hasMore = bufferedHasMore || providerHasMore;

    // The site does not expose a stable API total. Keep pagination open while
    // any category advertises a next page, but never claim fewer items than
    // we have already discovered.
    final minimumKnown = merged.length;
    final totalCount = hasMore
        ? math.max(minimumKnown, (logicalPage + 1) * logicalPageSize)
        : minimumKnown;

    return SourceSearchPage(
      items: selected,
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  Future<SourceSearchPage?> _searchCategoryPage({
    required String category,
    required String keyword,
    required int page,
  }) async {
    try {
      final adapter = HtmlAudioSiteSourceAdapter(
        kind: UnifiedSourceKind.asmr18,
        baseUrl: baseUrl,
        cacheNamespace: 'asmr18:$category',
        catalogUrlBuilder: (query, providerPage) =>
            _categoryCatalogUrl(category, query, providerPage),
        detailUrlMatcher: _isDetailUrl,
        dio: _client,
      );
      return await adapter.search(
        keyword: keyword,
        page: page,
        pageSize: 200,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final canonical = ref.canonicalId ?? Asmr18PageParser.canonicalId(html);
    final parsedTitle = Asmr18PageParser.title(
      html,
      fallback: ref.title ?? ref.localId,
      canonical: canonical,
    );
    final cover =
        SourceHtmlParser.extractFirstImage(html, base: pageUri) ?? ref.coverUrl;
    final vas = Asmr18PageParser.voiceActors(html, canonical: canonical)
        .map(
          (name) => Va(
            id: 'asmr18-va:${SourceHtmlParser.stableNegativeId(name).abs()}',
            name: name,
          ),
        )
        .toList(growable: false);
    final tags = Asmr18PageParser.genres(html, canonical: canonical)
        .map(
          (name) => Tag(
            id: SourceHtmlParser.stableNegativeId('asmr18-tag:$name'),
            name: name,
          ),
        )
        .toList(growable: false);

    return Work(
      id: SourceHtmlParser.stableNegativeId(
        'asmr18:${canonical ?? ref.localId}',
      ),
      title: parsedTitle,
      name: Asmr18PageParser.circle(html, canonical: canonical) ?? ref.circle,
      vas: vas.isEmpty ? null : vas,
      tags: tags.isEmpty ? null : tags,
      release: Asmr18PageParser.releaseDate(html, canonical: canonical),
      duration:
          Asmr18PageParser.totalDurationSeconds(html) ?? ref.durationSeconds,
      images: cover == null ? null : <String>[cover],
      description: SourceHtmlParser.extractMetaContent(html, 'description'),
      sourceUrl: ref.detailUrl,
      sourceId: canonical,
    );
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    final html = await _getHtml(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final canonical = ref.canonicalId ?? Asmr18PageParser.canonicalId(html);
    final chapters = Asmr18PageParser.chapters(html);
    final media = await _resolveMedia(
      html,
      pageUri,
      canonical: canonical,
    );
    if (media == null) return const [];

    final headers = <String, String>{
      'Referer': ref.detailUrl,
      'Origin': baseUrl,
      'User-Agent': _userAgent,
    };
    final mediaHash =
        'asmr18:${ref.localId}:media:${SourceHtmlParser.stableNegativeId(media).abs()}';

    if (chapters.isEmpty) {
      return <dynamic>[
        <String, dynamic>{
          'title': SourceHtmlParser.basenameFromUrl(media, 0),
          'type': 'audio',
          'hash': mediaHash,
          'sourceTrackId': 'full',
          'mediaStreamUrl': media,
          'headers': headers,
        },
      ];
    }

    return chapters.map((chapter) {
      return <String, dynamic>{
        'title': chapter.title,
        'type': 'audio',
        'hash': mediaHash,
        'sourceTrackId': chapter.id,
        'mediaStreamUrl': media,
        'startOffset': chapter.startSeconds,
        if (chapter.endSeconds != null) 'endOffset': chapter.endSeconds!,
        if (chapter.durationSeconds != null)
          'duration': chapter.durationSeconds!,
        'headers': headers,
      };
    }).toList(growable: false);
  }

  Future<String?> _resolveMedia(
    String html,
    Uri pageUri, {
    required String? canonical,
  }) async {
    final candidates = <String>[
      ...Asmr18PageParser.playableCandidates(html, pageUri: pageUri),
    ];

    // Legacy CDN patterns are retained only as a verified fallback. Actual
    // URLs exposed by the current player/packed script always win.
    if (canonical != null && canonical.toUpperCase().startsWith('RJ')) {
      final id = canonical.toUpperCase();
      candidates.addAll(<String>[
        'https://cdn3.cloudintech.net/file/$id/$id.m3u8',
        'https://cdn3.cloudintech.net/file/$id/1.m3u8',
      ]);
    }

    final unique = <String>{...candidates};
    final direct = unique.where((url) => !_looksHls(url));
    final hls = unique.where(_looksHls);
    for (final candidate in <String>[...direct, ...hls]) {
      if (await _probe(candidate, pageUri)) return candidate;
    }
    return null;
  }

  Future<bool> _probe(String url, Uri referer) async {
    final headers = <String, String>{
      'Referer': referer.toString(),
      'Origin': baseUrl,
      'User-Agent': _userAgent,
    };
    try {
      if (_looksHls(url)) {
        final response = await _client.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: headers,
            sendTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8),
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        return (response.data ?? '').contains('#EXTM3U');
      }

      final response = await _client.head<void>(
        url,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
        ),
      );
      return response.statusCode != null;
    } catch (_) {
      final uri = Uri.tryParse(url);
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          _looksDirectAudio(url);
    }
  }

  bool _looksHls(String url) =>
      Uri.tryParse(url)?.path.toLowerCase().endsWith('.m3u8') == true;

  bool _looksDirectAudio(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return const [
      '.mp3',
      '.m4a',
      '.aac',
      '.ogg',
      '.opus',
      '.wav',
      '.flac',
      '.m4b',
    ].any(path.endsWith);
  }

  Future<String> _getHtml(String url) async {
    final response = await _client.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Referer': '$baseUrl/',
          'User-Agent': _userAgent,
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    return response.data ?? '';
  }
}

String _categoryCatalogUrl(
  String category,
  String keyword,
  int page,
) {
  final encoded = Uri.encodeQueryComponent(keyword);
  final prefix = '${Asmr18SourceAdapter.baseUrl}/$category/';
  if (keyword.isEmpty) {
    return page <= 1 ? prefix : '${prefix}page/$page/';
  }
  return page <= 1
      ? '${prefix}?s=$encoded'
      : '${prefix}page/$page/?s=$encoded';
}

String _catalogUrl(String keyword, int page) {
  final encoded = Uri.encodeQueryComponent(keyword);
  const prefix = '${Asmr18SourceAdapter.baseUrl}/boys/';
  if (keyword.isEmpty) {
    return page <= 1 ? prefix : '${prefix}page/$page/';
  }
  return page <= 1
      ? '$prefix?s=$encoded'
      : '${prefix}page/$page/?s=$encoded';
}

bool _isDetailUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host != 'asmr18.fans') return false;
  return RegExp(
    r'^/(?:boys|girls|allages|all-ages)/(?:rj|bj)\d+/?',
    caseSensitive: false,
  ).hasMatch(uri.path);
}
