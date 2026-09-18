import '../models/work.dart';
import '../services/kikoeru_api_service.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class AsmrOneSourceAdapter implements UnifiedSourceAdapter {
  final KikoeruApiService api;

  const AsmrOneSourceAdapter(this.api);

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.asmrOne;

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    final trimmedKeyword = keyword.trim();
    final result = trimmedKeyword.isEmpty
        ? await api.getWorks(
            page: page,
            pageSize: pageSize,
            order: 'create_date',
            sort: 'desc',
            subtitle: 0,
          )
        : await api.searchWorks(
            keyword: trimmedKeyword,
            page: page,
            pageSize: pageSize,
            order: 'create_date',
            sort: 'desc',
            subtitle: 0,
          );

    final rawWorks = (result['works'] as List?) ?? const [];
    final items = <SourceWorkCandidate>[];
    for (final item in rawWorks) {
      final work = Work.fromJson(Map<String, dynamic>.from(item as Map));
      final canonical = SourceHtmlParser.extractCanonicalId(
        work.sourceId ?? work.title,
      );
      final detailUrl = work.sourceUrl ??
          'https://www.asmr.one/work/${work.sourceId ?? work.id}';
      final cover =
          work.images?.isNotEmpty == true ? work.images!.first : null;
      items.add(
        SourceWorkCandidate(
          work: work,
          ref: UnifiedSourceRef(
            source: kind,
            localId: work.id.toString(),
            canonicalId: canonical,
            detailUrl: detailUrl,
            coverUrl: cover,
            title: work.title,
            circle: work.name,
            durationSeconds: work.duration,
          ),
        ),
      );
    }

    final pagination = result['pagination'] as Map<String, dynamic>?;
    final totalCount =
        (pagination?['totalCount'] as num?)?.toInt() ?? items.length;
    final totalPages = totalCount <= 0 ? 1 : (totalCount / pageSize).ceil();
    return SourceSearchPage(
      items: items,
      totalCount: totalCount,
      hasMore: page < totalPages,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    final id = int.parse(ref.localId);
    return Work.fromJson(await api.getWork(id));
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    return api.getWorkTracks(int.parse(ref.localId));
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    try {
      await api.getWorks(
        page: 1,
        pageSize: 1,
        order: 'create_date',
        sort: 'desc',
        subtitle: 0,
      );
      return UnifiedSourceHealth.healthy;
    } catch (_) {
      return UnifiedSourceHealth.broken;
    }
  }
}
