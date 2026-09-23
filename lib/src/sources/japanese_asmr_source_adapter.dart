import 'dart:async';

import 'package:dio/dio.dart';

import '../models/work.dart';
import 'html_audio_site_source_adapter.dart';
import 'japanese_asmr_verified_catalog.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class JapaneseAsmrChapter {
  final String id;
  final String title;
  final int startSeconds;
  final int? endSeconds;

  const JapaneseAsmrChapter({
    required this.id,
    required this.title,
    required this.startSeconds,
    this.endSeconds,
  });

  int? get durationSeconds {
    final end = endSeconds;
    if (end == null || end < startSeconds) return null;
    return end - startSeconds;
  }
}

class JapaneseAsmrPageParser {
  const JapaneseAsmrPageParser._();

  static String? canonicalId(String html) =>
      SourceHtmlParser.extractCanonicalId(html);

  static String title(String html, {String? fallback, String? canonical}) {
    var value = SourceHtmlParser.extractTitle(html) ?? fallback ?? '';
    value = SourceHtmlParser.stripTags(value)
        .replaceFirst(
          RegExp(
            r'\s*[\-–—|]\s*Japanese\s+ASMR\s*$',
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

  static String? circle(String html) {
    for (final line in _plainLines(html)) {
      final match = RegExp(r'^\[\d{6}\]\[([^\]]+)\]').firstMatch(line);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? releaseDate(String html) {
    for (final line in _plainLines(html)) {
      final match = RegExp(r'^\[(\d{2})(\d{2})(\d{2})\]').firstMatch(line);
      if (match == null) continue;
      final year = 2000 + int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  static List<String> voiceActors(String html) {
    final lines = _plainLines(html);
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final match = RegExp(r'^CV\s*:\s*(.*)$', caseSensitive: false)
          .firstMatch(line);
      if (match == null) continue;
      var value = match.group(1)?.trim() ?? '';
      if (value.isEmpty && index + 1 < lines.length) {
        value = lines[index + 1].trim();
      }
      return value
          .split(RegExp(r'[,、/]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const [];
  }

  static List<String> tags(String html) {
    final result = <String>{};
    final anchors = RegExp(
      r'''<a\b[^>]*href=["'][^"']*/tag/[^"']*["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in anchors.allMatches(html)) {
      final value = SourceHtmlParser.stripTags(match.group(1) ?? '').trim();
      if (value.isNotEmpty) result.add(value);
    }
    return result.toList(growable: false);
  }

  static int? totalDurationSeconds(String html) {
    final text = SourceHtmlParser.stripTags(
      html
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</(?:p|div|li|tr|td|h[1-6])>', caseSensitive: false), '\n'),
    );

    final japanese = RegExp(
      r'(?:総再生時間|収録時間|再生時間)\s*[:：]?\s*'
      r'(?:(\d+)\s*時間)?\s*(?:(\d+)\s*分)?\s*(?:(\d+)\s*秒)?',
    ).firstMatch(text);
    if (japanese != null) {
      final hours = int.tryParse(japanese.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(japanese.group(2) ?? '') ?? 0;
      final seconds = int.tryParse(japanese.group(3) ?? '') ?? 0;
      final total = hours * 3600 + minutes * 60 + seconds;
      if (total > 0) return total;
    }

    final label = RegExp(
      r'(?:total\s*(?:duration|time)|総再生時間|収録時間)[^0-9]{0,20}'
      r'((?:\d{1,2}:)?\d{1,2}:\d{2})',
      caseSensitive: false,
    ).firstMatch(text);
    return label == null ? null : _timestampSeconds(label.group(1)!);
  }

  static List<JapaneseAsmrChapter> chapters(
    String html, {
    int? totalDurationSeconds,
  }) {
    final lines = _plainLines(html);
    final raw = <({int start, String title})>[];
    final seenStarts = <int>{};

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final timeMatch = RegExp(r'\b(\d{1,2}:\d{2}:\d{2})\b').firstMatch(line);
      if (timeMatch == null) continue;
      final start = _timestampSeconds(timeMatch.group(1)!);
      if (start == null || !seenStarts.add(start)) continue;

      var title = line.substring(timeMatch.end)
          .replaceFirst(RegExp(r'^[\s|｜:：\-–—]+'), '')
          .trim();
      if (title.isEmpty && index + 1 < lines.length) {
        final candidate = lines[index + 1].trim();
        if (!RegExp(r'^\d{1,2}:\d{2}:\d{2}\b').hasMatch(candidate)) {
          title = candidate;
        }
      }
      title = title
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceFirst(RegExp(r'^[|｜]+'), '')
          .trim();
      if (title.isEmpty) title = 'Track ${raw.length + 1}';
      raw.add((start: start, title: title));
    }

    raw.sort((a, b) => a.start.compareTo(b.start));
    final result = <JapaneseAsmrChapter>[];
    for (var index = 0; index < raw.length; index++) {
      final current = raw[index];
      final nextStart = index + 1 < raw.length ? raw[index + 1].start : null;
      final end = nextStart ??
          (totalDurationSeconds != null &&
                  totalDurationSeconds > current.start
              ? totalDurationSeconds
              : null);
      result.add(
        JapaneseAsmrChapter(
          id: 'chapter-${index + 1}',
          title: current.title,
          startSeconds: current.start,
          endSeconds: end,
        ),
      );
    }
    return result;
  }

  static List<String> embeddedPlayerUrls(String html, Uri pageUri) {
    final result = <String>{};
    final iframes = RegExp(
      r'''<iframe\b[^>]*(?:src|data-src)=["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in iframes.allMatches(html)) {
      final resolved = SourceHtmlParser.resolveUrl(match.group(1), base: pageUri);
      if (resolved == null) continue;
      final uri = Uri.tryParse(resolved);
      if (uri == null || !uri.hasScheme) continue;
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;

      final contextStart = match.start > 1200 ? match.start - 1200 : 0;
      final context = SourceHtmlParser.stripTags(
        html.substring(contextStart, match.end),
      ).toLowerCase();
      final attributes = (match.group(0) ?? '').toLowerCase();
      final hint = '$context $attributes ${resolved.toLowerCase()}';
      final looksLikePlayer = hint.contains('player 1') ||
          hint.contains('player 2') ||
          hint.contains('audio player') ||
          hint.contains('audio-player') ||
          hint.contains('audioplayer');
      final looksLikeAd =
          context.contains('video ads') || hint.contains('doubleclick');
      if (!looksLikePlayer || looksLikeAd) continue;
      result.add(resolved);
    }
    return result.toList(growable: false);
  }

  static List<String> _plainLines(String html) {
    final separated = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(
            r'</(?:p|div|li|tr|td|th|h[1-6]|table|section|article)>',
            caseSensitive: false,
          ),
          '\n',
        );
    return separated
        .split('\n')
        .map(SourceHtmlParser.stripTags)
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
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

class JapaneseAsmrGatewayParser {
  const JapaneseAsmrGatewayParser._();

  static const String gatewayBaseUrl = 'https://r.jina.ai/';

  static String gatewayUrl(String sourceUrl) => gatewayBaseUrl + sourceUrl;

  static List<String> gatewayUrls(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null) return <String>[gatewayUrl(sourceUrl)];

    final httpsSource = uri.replace(scheme: 'https').toString();
    final httpSource = uri.replace(scheme: 'http').toString();
    return <String>{
      gatewayUrl(httpsSource),
      gatewayUrl(httpSource),
    }.toList(growable: false);
  }

  static String? coverUrl(String markdown) {
    return RegExp(
      r'''!\[[^\]]*\]\((https?://(?:pic|img|pic1)\.weeabo0\.xyz/[^)\s]+)\)''',
      caseSensitive: false,
    ).firstMatch(markdown)?.group(1);
  }

  static String normalizeDetail(String markdown) {
    final out = StringBuffer();

    final title = RegExp(
      r'^Title:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(markdown)?.group(1)?.trim();
    if (title != null && title.isNotEmpty) {
      out.writeln('<title>${_escapeHtml(title)}</title>');
    }

    final metadata = RegExp(
      r'^\*\*(\[\d{6}\]\[[^\]]+\].*?)\*\*\s*$',
      multiLine: true,
    ).firstMatch(markdown)?.group(1)?.trim();
    if (metadata != null && metadata.isNotEmpty) {
      out.writeln('<p>${_escapeHtml(metadata)}</p>');
    }

    final voice = RegExp(
      r'^CV\s*:\s*(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(markdown)?.group(0)?.trim();
    if (voice != null && voice.isNotEmpty) {
      out.writeln('<p>${_escapeHtml(voice)}</p>');
    }

    final cover = coverUrl(markdown);
    if (cover != null) {
      out.writeln('<img src="$cover">');
    }

    final chapters = RegExp(
      r'''^\[(\d{1,2}:\d{2}:\d{2})\]\([^)]+\)\[([^\]]+)\]\([^)]+\)\s*$''',
      multiLine: true,
    );
    for (final match in chapters.allMatches(markdown)) {
      out.writeln(
        '<p>${match.group(1)} ${_escapeHtml(match.group(2) ?? '')}</p>',
      );
    }

    out.writeln(markdown);
    return out.toString();
  }

  static List<SourceWorkCandidate> catalog(
    String markdown, {
    int page = 1,
    required int pageSize,
  }) {
    final headings = RegExp(
      r'''^##\s+\[([^\]]+)\]\((https?://(?:www\.)?japaneseasmr\.com/(\d+)/?)\)\s*$''',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(markdown).toList(growable: false);
    final results = <SourceWorkCandidate>[];
    final seen = <String>{};

    for (var index = 0; index < headings.length; index++) {
      final match = headings[index];
      final detailUrl = match.group(2)!;
      if (!seen.add(detailUrl)) continue;

      final end = index + 1 < headings.length
          ? headings[index + 1].start
          : markdown.length;
      final context = markdown.substring(match.start, end);
      final canonical = SourceHtmlParser.extractCanonicalId(context);
      final numericId = match.group(3)!;
      final localId = canonical ?? numericId;
      final title = (match.group(1) ?? '').trim();
      final cover = coverUrl(context);
      final normalized = normalizeDetail(context);
      final circle = JapaneseAsmrPageParser.circle(normalized);
      final release = JapaneseAsmrPageParser.releaseDate(normalized);
      final voices = JapaneseAsmrPageParser.voiceActors(normalized)
          .map(
            (name) => Va(
              id: 'japaneseasmr-va:${SourceHtmlParser.stableNegativeId(name).abs()}',
              name: name,
            ),
          )
          .toList(growable: false);

      final ref = UnifiedSourceRef(
        source: UnifiedSourceKind.japaneseAsmr,
        localId: localId,
        canonicalId: canonical,
        detailUrl: detailUrl,
        coverUrl: cover,
        title: title,
        circle: circle,
      );
      final work = Work(
        id: SourceHtmlParser.stableNegativeId('japaneseasmr:$localId'),
        title: title.isEmpty ? (canonical ?? numericId) : title,
        name: circle,
        age: 'R18',
        release: release,
        vas: voices.isEmpty ? null : voices,
        images: cover == null ? null : <String>[cover],
        sourceUrl: detailUrl,
        sourceId: canonical,
      );
      results.add(SourceWorkCandidate(work: work, ref: ref));
      if (results.length >= pageSize) break;
    }
    return results;
  }

  static String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

class JapaneseAsmrLastKnownGood {
  const JapaneseAsmrLastKnownGood._();

  static List<JapaneseAsmrVerifiedCatalogEntry> get entries =>
      japaneseAsmrVerifiedCatalog;

  static String get catalogMarkdown => entries.map((entry) {
        final metadata = <String>[
          if (entry.releaseCode.isNotEmpty) entry.releaseCode,
          if (entry.circle.isNotEmpty) entry.circle,
        ];
        final metadataLine = metadata.isEmpty
            ? '[${entry.rj}]'
            : '[${metadata.join('][')}] ${entry.title} [${entry.rj}]';
        return '''
## [${entry.title}](${entry.detailUrl})

[![Image](${entry.coverUrl})](${entry.detailUrl})

**$metadataLine**

CV: ${entry.voice}
''';
      }).join('\n');

  static String? detailMarkdown(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null) return null;
    final segments =
        uri.path.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    final numericId = segments.last;

    JapaneseAsmrVerifiedCatalogEntry? selected;
    for (final entry in entries) {
      if (entry.numericId == numericId) {
        selected = entry;
        break;
      }
    }
    if (selected == null) return null;

    final entry = selected;
    final metadata = <String>[
      if (entry.releaseCode.isNotEmpty) entry.releaseCode,
      if (entry.circle.isNotEmpty) entry.circle,
    ];
    final metadataLine = metadata.isEmpty
        ? '[${entry.rj}]'
        : '[${metadata.join('][')}] ${entry.title} [${entry.rj}]';
    return '''
Title: ${entry.title} – Japanese ASMR

![Image](${entry.coverUrl})

**$metadataLine**

CV: ${entry.voice}

[Audio](${entry.mediaUrl})
''';
  }
}

class JapaneseAsmrSourceAdapter extends HtmlAudioSiteSourceAdapter {
  static const String baseUrl = 'https://japaneseasmr.com';
  static const String _userAgent = 'Hiraukan/3.8 UnifiedSources';

  final Dio _client;

  factory JapaneseAsmrSourceAdapter({Dio? dio}) {
    final client = dio ?? Dio();
    return JapaneseAsmrSourceAdapter._(client);
  }

  JapaneseAsmrSourceAdapter._(Dio client)
      : _client = client,
        super(
          kind: UnifiedSourceKind.japaneseAsmr,
          baseUrl: baseUrl,
          cacheNamespace: 'japaneseasmr',
          catalogUrlBuilder: _catalogUrl,
          detailUrlMatcher: _isDetailUrl,
          dio: client,
        );

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    try {
      final direct = await super.search(
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
      if (direct.items.isNotEmpty) return direct;
    } catch (_) {
      // Fall through to the gateway below.
    }

    final logicalPage = page < 1 ? 1 : page;
    try {
      final markdown = await _getGatewayText(
        _catalogUrl(keyword.trim(), logicalPage),
      );
      final items = JapaneseAsmrGatewayParser.catalog(
        markdown,
        pageSize: pageSize,
      );
      if (items.isNotEmpty) {
        return SourceSearchPage(
          items: items,
          totalCount: ((logicalPage - 1) * pageSize) + items.length,
          hasMore: items.length >= pageSize,
        );
      }
    } catch (_) {
      // Fall through to the verified last-known-good snapshot.
    }

    return _searchLastKnownGood(
      keyword: keyword,
      page: logicalPage,
      pageSize: pageSize,
    );
  }

  SourceSearchPage _searchLastKnownGood({
    required String keyword,
    required int page,
    required int pageSize,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    var items = JapaneseAsmrGatewayParser.catalog(
      JapaneseAsmrLastKnownGood.catalogMarkdown,
      pageSize: JapaneseAsmrLastKnownGood.entries.length,
    );
    if (normalizedKeyword.isNotEmpty) {
      items = items.where((candidate) {
        final haystack = <String>[
          candidate.work.title,
          candidate.work.name ?? '',
          candidate.ref.canonicalId ?? '',
          candidate.ref.localId,
        ].join(' ').toLowerCase();
        return haystack.contains(normalizedKeyword);
      }).toList(growable: false);
    }

    final safePageSize = pageSize < 1 ? 1 : pageSize;
    final start = (page - 1) * safePageSize;
    if (start >= items.length) {
      return SourceSearchPage(
        items: const [],
        totalCount: items.length,
        hasMore: false,
      );
    }
    final selected =
        items.skip(start).take(safePageSize).toList(growable: false);
    return SourceSearchPage(
      items: selected,
      totalCount: items.length,
      hasMore: start + selected.length < items.length,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final html = await _getSourceText(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final canonical = ref.canonicalId ?? JapaneseAsmrPageParser.canonicalId(html);
    final parsedTitle = JapaneseAsmrPageParser.title(
      html,
      fallback: ref.title ?? ref.localId,
      canonical: canonical,
    );
    final cover =
        SourceHtmlParser.extractFirstImage(html, base: pageUri) ?? ref.coverUrl;
    final totalDuration = JapaneseAsmrPageParser.totalDurationSeconds(html);
    final circle = JapaneseAsmrPageParser.circle(html) ?? ref.circle;
    final vas = JapaneseAsmrPageParser.voiceActors(html)
        .map(
          (name) => Va(
            id: 'japaneseasmr-va:${SourceHtmlParser.stableNegativeId(name).abs()}',
            name: name,
          ),
        )
        .toList(growable: false);
    final tags = JapaneseAsmrPageParser.tags(html)
        .map(
          (name) => Tag(
            id: SourceHtmlParser.stableNegativeId('japaneseasmr-tag:$name'),
            name: name,
          ),
        )
        .toList(growable: false);

    return Work(
      id: SourceHtmlParser.stableNegativeId(
        'japaneseasmr:${canonical ?? ref.localId}',
      ),
      title: parsedTitle,
      name: circle,
      vas: vas.isEmpty ? null : vas,
      tags: tags.isEmpty ? null : tags,
      release: JapaneseAsmrPageParser.releaseDate(html),
      duration: totalDuration ?? ref.durationSeconds,
      images: cover == null ? null : <String>[cover],
      description: SourceHtmlParser.extractMetaContent(html, 'description'),
      sourceUrl: ref.detailUrl,
      sourceId: canonical,
    );
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    final html = await _getSourceText(ref.detailUrl);
    final pageUri = Uri.parse(ref.detailUrl);
    final totalDuration = JapaneseAsmrPageParser.totalDurationSeconds(html);
    final chapters = JapaneseAsmrPageParser.chapters(
      html,
      totalDurationSeconds: totalDuration,
    );
    final media = await _resolveMedia(html, pageUri);
    if (media == null) return const [];

    final headers = <String, String>{
      'Referer': ref.detailUrl,
      'Origin': baseUrl,
      'User-Agent': _userAgent,
    };
    final mediaHash =
        'japanese_asmr:${ref.localId}:media:${SourceHtmlParser.stableNegativeId(media).abs()}';

    if (chapters.isEmpty) {
      return <dynamic>[
        <String, dynamic>{
          'title': SourceHtmlParser.basenameFromUrl(media, 0),
          'type': 'audio',
          'hash': mediaHash,
          'sourceTrackId': 'full',
          'mediaStreamUrl': media,
          if (totalDuration != null) 'duration': totalDuration,
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

  Future<String?> _resolveMedia(String html, Uri pageUri) async {
    final directCandidates = SourceHtmlParser.extractPlayableUrls(
      html,
      base: pageUri,
    );
    final direct = await _firstReachable(directCandidates, pageUri);
    if (direct != null) return direct;

    // Player 1 / Player 2 are commonly embedded documents. Preserve DOM order
    // so the first usable player wins, and only continue when it cannot resolve.
    for (final playerUrl
        in JapaneseAsmrPageParser.embeddedPlayerUrls(html, pageUri)) {
      try {
        final playerHtml = await _getHtml(
          playerUrl,
          referer: pageUri.toString(),
        );
        final candidates = SourceHtmlParser.extractPlayableUrls(
          playerHtml,
          base: Uri.parse(playerUrl),
        );
        final resolved = await _firstReachable(candidates, Uri.parse(playerUrl));
        if (resolved != null) return resolved;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<String?> _firstReachable(
    List<String> candidates,
    Uri referer,
  ) async {
    if (candidates.isEmpty) return null;
    final direct = candidates.where((url) => !_looksHls(url));
    final hls = candidates.where(_looksHls);
    for (final candidate in <String>[...direct, ...hls]) {
      if (await _probe(candidate, referer)) return candidate;
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
      // A resolver probe is advisory. The Android native player may still
      // reach a media host that Dio cannot (different redirect/CDN/network
      // handling), so a syntactically valid media URL must still be allowed
      // through. A probe failure is not equivalent to playback failure.
      final uri = Uri.tryParse(url);
      return uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          (_looksDirectAudio(url) || _looksHls(url));
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

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    final direct = await super.checkHealth();
    if (direct != UnifiedSourceHealth.broken) return direct;

    try {
      final markdown = await _getGatewayText('$baseUrl/');
      return markdown.contains('japaneseasmr.com')
          ? UnifiedSourceHealth.degraded
          : UnifiedSourceHealth.broken;
    } catch (_) {
      final lastKnownGood = JapaneseAsmrGatewayParser.catalog(
        JapaneseAsmrLastKnownGood.catalogMarkdown,
        pageSize: 1,
      );
      return lastKnownGood.isNotEmpty
          ? UnifiedSourceHealth.degraded
          : UnifiedSourceHealth.broken;
    }
  }

  Future<String> _getSourceText(String url) async {
    try {
      final direct = await _getHtml(url);
      final canonical = JapaneseAsmrPageParser.canonicalId(direct);
      final hasWorkSignals = canonical != null ||
          direct.contains('work_title_jp') ||
          direct.contains('plyr-chapter-playlist') ||
          SourceHtmlParser.extractPlayableUrls(
            direct,
            base: Uri.tryParse(url),
          ).isNotEmpty;
      if (hasWorkSignals) return direct;
    } catch (_) {
      // Fall through to the read-only gateway.
    }

    try {
      final markdown = await _getGatewayText(url);
      return JapaneseAsmrGatewayParser.normalizeDetail(markdown);
    } catch (_) {
      final lastKnownGood = JapaneseAsmrLastKnownGood.detailMarkdown(url);
      if (lastKnownGood != null) {
        return JapaneseAsmrGatewayParser.normalizeDetail(lastKnownGood);
      }
      rethrow;
    }
  }

  Future<String> _getGatewayText(String sourceUrl) async {
    Object? lastError;
    for (final gatewayUrl
        in JapaneseAsmrGatewayParser.gatewayUrls(sourceUrl)) {
      try {
        final response = await _client.get<String>(
          gatewayUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: const <String, String>{
              'User-Agent': _userAgent,
              'Accept': 'text/plain,*/*;q=0.8',
            },
            sendTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 22),
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        final text = response.data ?? '';
        if (text.trim().isNotEmpty) return text;
        lastError = StateError(
          'JapaneseASMR gateway returned an empty response: $gatewayUrl',
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('JapaneseASMR gateways failed: $lastError');
  }

  Future<String> _getHtml(
    String url, {
    String? referer,
  }) async {
    final response = await _client.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, String>{
          'Referer': referer ?? '$baseUrl/',
          'User-Agent': _userAgent,
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    return response.data ?? '';
  }
}

String _catalogUrl(String keyword, int page) {
  final encoded = Uri.encodeQueryComponent(keyword);
  if (keyword.isEmpty) {
    return page <= 1
        ? '$JapaneseAsmrSourceAdapter.baseUrl/'
        : '$JapaneseAsmrSourceAdapter.baseUrl/page/$page/';
  }
  return page <= 1
      ? '$JapaneseAsmrSourceAdapter.baseUrl/?s=$encoded'
      : '$JapaneseAsmrSourceAdapter.baseUrl/page/$page/?s=$encoded';
}

bool _isDetailUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host != 'japaneseasmr.com') return false;
  return RegExp(r'^/\d+/?$').hasMatch(uri.path);
}
