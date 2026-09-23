import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class AsmrHentaiApiCodec {
  const AsmrHentaiApiCodec._();

  static Uint8List encode(Object value) {
    final source = utf8.encode(jsonEncode(value));
    return Uint8List.fromList(
      source.map((byte) => (~byte) & 0xff).toList().reversed.toList(),
    );
  }

  static Object? decode(List<int> value) {
    final decoded = value
        .map((byte) => (~byte) & 0xff)
        .toList()
        .reversed
        .toList(growable: false);
    return jsonDecode(utf8.decode(decoded));
  }
}

class AsmrHentaiApiParser {
  const AsmrHentaiApiParser._();

  static List<Map<String, dynamic>> catalogEntries(
    Map<String, dynamic> payload, {
    required bool discover,
  }) {
    final raw = payload[discover ? 'b' : 'a'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  static int pageCount(
    Map<String, dynamic> payload, {
    required bool discover,
  }) {
    final raw = payload[discover ? 'c' : 'b'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static List<dynamic> buildTrackTree(String workId, Object? rawTree) {
    if (rawTree is! List) return const [];
    final result = <dynamic>[];
    for (final raw in rawTree) {
      if (raw is! Map) continue;
      result.addAll(_nodeTracks(workId, Map<String, dynamic>.from(raw)));
    }
    return result;
  }

  static List<dynamic> _nodeTracks(
    String workId,
    Map<String, dynamic> node,
  ) {
    final children = <dynamic>[];
    final direct = node['b'];
    if (direct is List) {
      for (final raw in direct) {
        if (raw is! Map) continue;
        final track = Map<String, dynamic>.from(raw);
        final mediaId = track['a']?.toString().trim();
        if (mediaId == null || mediaId.isEmpty) continue;
        final title = track['b']?.toString().trim();
        final duration = track['c'];
        final durationSeconds = duration is num ? duration.toInt() : null;
        children.add(<String, dynamic>{
          'title': title == null || title.isEmpty ? mediaId : title,
          'type': 'audio',
          'hash': 'asmr_hentai_net:$workId:$mediaId',
          'sourceTrackId': mediaId,
          'mediaStreamUrl':
              '${AsmrHentaiNetSourceAdapter.apiBaseUrl}/storage/$workId/$mediaId.opus',
          'startOffset': 0,
          if (durationSeconds != null) ...<String, dynamic>{
            'duration': durationSeconds,
            'endOffset': durationSeconds,
          },
          'headers': const <String, String>{
            'Referer': AsmrHentaiNetSourceAdapter.baseUrl,
            'Origin': AsmrHentaiNetSourceAdapter.baseUrl,
            'User-Agent': 'Hiraukan/3.8 UnifiedSources',
          },
        });
      }
    }

    final nested = node['c'];
    if (nested is List) {
      for (final raw in nested) {
        if (raw is! Map) continue;
        children.addAll(
          _nodeTracks(workId, Map<String, dynamic>.from(raw)),
        );
      }
    }

    if (children.isEmpty) return const [];
    final title = node['a']?.toString().trim() ?? '';
    if (title.isEmpty) return children;
    return [
      <String, dynamic>{
        'title': title,
        'type': 'folder',
        'children': children,
      },
    ];
  }

  static int? primaryDurationSeconds(Object? rawTree) {
    if (rawTree is! List || rawTree.isEmpty) return null;
    var best = 0;
    for (final raw in rawTree) {
      if (raw is! Map) continue;
      final duration = _nodeDuration(Map<String, dynamic>.from(raw));
      if (duration > best) best = duration;
    }
    return best == 0 ? null : best;
  }

  static int _nodeDuration(Map<String, dynamic> node) {
    var directTotal = 0;
    final direct = node['b'];
    if (direct is List) {
      for (final raw in direct) {
        if (raw is Map && raw['c'] is num) {
          directTotal += (raw['c'] as num).toInt();
        }
      }
    }

    var longestChild = 0;
    final nested = node['c'];
    if (nested is List) {
      for (final raw in nested) {
        if (raw is! Map) continue;
        final value = _nodeDuration(Map<String, dynamic>.from(raw));
        if (value > longestChild) longestChild = value;
      }
    }
    return directTotal + longestChild;
  }
}

class AsmrHentaiNetSourceAdapter
    implements UnifiedSourceAdapter, CatalogCountAwareSourceAdapter {
  static const String baseUrl = 'https://asmrhentai.net';
  static const String apiBaseUrl = 'https://newapi.asmrhentai.net';
  static const int _apiPageSize = 24;
  static const String _language = 'ja';

  final Dio _dio;
  final Map<String, int> _totalCountCache = <String, int>{};
  final Map<String, Future<Map<String, dynamic>>> _infoRequests =
      <String, Future<Map<String, dynamic>>>{};

  AsmrHentaiNetSourceAdapter({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 24)
      ..headers['User-Agent'] = 'Hiraukan/3.8 UnifiedSources';
  }

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.asmrHentaiNet;

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
    final firstApiPage = startIndex ~/ _apiPageSize;
    final offset = startIndex % _apiPageSize;

    final first = await _loadApiPage(trimmedKeyword, firstApiPage);
    if (first.pageCount <= 0 || firstApiPage >= first.pageCount) {
      return SourceSearchPage(
        items: const [],
        totalCount: _totalCountCache[cacheKey] ?? 0,
        hasMore: false,
      );
    }

    var finalApiPage =
        (startIndex + logicalPageSize - 1) ~/ _apiPageSize;
    if (finalApiPage >= first.pageCount) {
      finalApiPage = first.pageCount - 1;
    }

    final pages = <int, _AsmrHentaiApiPage>{firstApiPage: first};
    if (finalApiPage > firstApiPage) {
      final pageNumbers = [
        for (var index = firstApiPage + 1; index <= finalApiPage; index++)
          index,
      ];
      final loaded = await Future.wait(
        pageNumbers.map((index) => _loadApiPage(trimmedKeyword, index)),
      );
      for (var index = 0; index < pageNumbers.length; index++) {
        pages[pageNumbers[index]] = loaded[index];
      }
    }

    var totalCount = _totalCountCache[cacheKey];
    if (totalCount == null) {
      final lastIndex = first.pageCount - 1;
      final last = pages[lastIndex] ??
          (lastIndex == firstApiPage
              ? first
              : await _loadApiPage(trimmedKeyword, lastIndex));
      totalCount = (lastIndex * _apiPageSize) + last.entries.length;
      _totalCountCache[cacheKey] = totalCount;
    }

    final entries = <Map<String, dynamic>>[];
    for (var index = firstApiPage; index <= finalApiPage; index++) {
      entries.addAll(pages[index]?.entries ?? const []);
    }
    final selected =
        entries.skip(offset).take(logicalPageSize).toList(growable: false);
    final candidates = selected
        .map(_candidateFromCatalogEntry)
        .whereType<SourceWorkCandidate>()
        .toList(growable: false);

    return SourceSearchPage(
      items: candidates,
      totalCount: totalCount,
      hasMore: startIndex + selected.length < totalCount,
    );
  }

  Future<_AsmrHentaiApiPage> _loadApiPage(
    String keyword,
    int pageIndex,
  ) async {
    final discover = keyword.isEmpty;
    final payload = discover
        ? <String, dynamic>{
            'a': _language,
            'b': pageIndex,
            'c': 0,
            'd': const <String>[],
          }
        : <String, dynamic>{
            'a': _language,
            'b': keyword,
            'c': '',
            'd': const <String>[],
            'e': pageIndex,
          };
    final response = await _postMap(
      discover ? '/Core/Discover' : '/Core/Search',
      payload,
    );
    return _AsmrHentaiApiPage(
      entries: AsmrHentaiApiParser.catalogEntries(
        response,
        discover: discover,
      ),
      pageCount: AsmrHentaiApiParser.pageCount(
        response,
        discover: discover,
      ),
    );
  }

  SourceWorkCandidate? _candidateFromCatalogEntry(
    Map<String, dynamic> entry,
  ) {
    final id = _normalizeWorkId(entry['a']?.toString());
    if (id == null) return null;
    final rawTitle = entry['b']?.toString().trim() ?? '';
    final rawCircle = entry['c']?.toString().trim() ?? '';
    final title = SourceHtmlParser.decodeEntities(
      rawTitle.isEmpty ? id : rawTitle,
    );
    final circle = rawCircle.isEmpty
        ? null
        : SourceHtmlParser.decodeEntities(rawCircle);
    final age = entry['d']?.toString();
    final detailUrl = baseUrl + '/' + id;
    final cover = _coverUrl(id);
    final ref = UnifiedSourceRef(
      source: kind,
      localId: id,
      canonicalId: id,
      detailUrl: detailUrl,
      coverUrl: cover,
      title: title,
      circle: circle,
    );
    final work = Work(
      id: SourceHtmlParser.stableNegativeId('asmrhentai-net:$id'),
      title: title,
      name: circle,
      age: age?.isEmpty == true ? null : age,
      images: [cover],
      sourceUrl: detailUrl,
      sourceId: id,
    );
    return SourceWorkCandidate(work: work, ref: ref);
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final workId = _workIdFromRef(ref);
    final info = await _loadInfo(workId);
    final title = SourceHtmlParser.decodeEntities(
      info['b']?.toString().trim().isNotEmpty == true
          ? info['b'].toString().trim()
          : (ref.title ?? workId),
    );
    final rawCircle = info['c']?.toString().trim() ?? '';
    final circle = rawCircle.isEmpty
        ? ref.circle
        : SourceHtmlParser.decodeEntities(rawCircle);
    final rawTags = info['f'];
    final tags = rawTags is List
        ? rawTags
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .map(
              (name) => Tag(
                id: SourceHtmlParser.stableNegativeId(
                  'asmrhentai-tag:$name',
                ),
                name: name,
              ),
            )
            .toList(growable: false)
        : null;
    final description = info['g']?.toString().trim();
    final rawTree = info['h'];
    final trackMaps = AsmrHentaiApiParser.buildTrackTree(workId, rawTree);

    return Work(
      id: SourceHtmlParser.stableNegativeId('asmrhentai-net:$workId'),
      title: title,
      name: circle,
      tags: tags,
      age: info['d']?.toString(),
      release: _releaseDate(info['e']),
      duration: AsmrHentaiApiParser.primaryDurationSeconds(rawTree),
      images: [_coverUrl(workId)],
      description:
          description == null || description.isEmpty ? null : description,
      children: _audioFilesFromMaps(trackMaps),
      sourceUrl: baseUrl + '/' + workId,
      sourceId: workId,
    );
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    final workId = _workIdFromRef(ref);
    final info = await _loadInfo(workId);
    return AsmrHentaiApiParser.buildTrackTree(workId, info['h']);
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    try {
      final response = await _postMap(
        '/Core/Discover',
        const <String, dynamic>{
          'a': _language,
          'b': 0,
          'c': 0,
          'd': <String>[],
        },
      );
      return AsmrHentaiApiParser.catalogEntries(
        response,
        discover: true,
      ).isNotEmpty
          ? UnifiedSourceHealth.healthy
          : UnifiedSourceHealth.degraded;
    } catch (_) {
      return UnifiedSourceHealth.broken;
    }
  }

  Future<Map<String, dynamic>> _loadInfo(String workId) async {
    final existing = _infoRequests[workId];
    if (existing != null) return existing;

    final request = _postMap(
      '/Core/Info',
      <String, dynamic>{'a': _language, 'b': workId},
    );
    _infoRequests[workId] = request;
    try {
      return await request;
    } catch (_) {
      _infoRequests.remove(workId);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<List<int>>(
      apiBaseUrl + path,
      data: AsmrHentaiApiCodec.encode(payload),
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {
          'Content-Type': 'f/s',
          'Accept-Language': '',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final raw = response.data;
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final decoded = AsmrHentaiApiCodec.decode(raw);
    if (decoded is! Map) {
      throw StateError('ASMR Hentai API returned an invalid response');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _workIdFromRef(UnifiedSourceRef ref) {
    final candidates = [
      ref.canonicalId,
      ref.localId,
      ref.detailUrl,
    ];
    for (final value in candidates) {
      final normalized = _normalizeWorkId(value);
      if (normalized != null) return normalized;
    }
    throw StateError('ASMR Hentai work id is missing');
  }

  String? _normalizeWorkId(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'RJ\d{1,10}',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(0)?.toUpperCase();
  }

  String _coverUrl(String workId) =>
      apiBaseUrl + '/storage/' + workId + '/cover.avif';

  String? _releaseDate(Object? raw) {
    final seconds = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (seconds == null || seconds <= 0) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return date.year.toString() + '-' + month + '-' + day;
  }

  List<AudioFile> _audioFilesFromMaps(List<dynamic> values) {
    final result = <AudioFile>[];
    for (final raw in values) {
      if (raw is! Map) continue;
      final value = Map<String, dynamic>.from(raw);
      final children = value['children'];
      final type = value['type']?.toString();
      if (type == 'folder') {
        result.add(
          AudioFile(
            title: value['title']?.toString() ?? 'Tracks',
            type: 'folder',
            children: children is List
                ? _audioFilesFromMaps(children)
                : const <AudioFile>[],
          ),
        );
        continue;
      }
      final url = value['mediaStreamUrl']?.toString();
      result.add(
        AudioFile(
          title: value['title']?.toString() ?? 'Track',
          type: 'audio',
          hash: value['hash']?.toString(),
          mediaDownloadUrl: url == null || url.isEmpty ? null : url,
          duration: value['duration'],
        ),
      );
    }
    return result;
  }
}

class _AsmrHentaiApiPage {
  final List<Map<String, dynamic>> entries;
  final int pageCount;

  const _AsmrHentaiApiPage({
    required this.entries,
    required this.pageCount,
  });
}
