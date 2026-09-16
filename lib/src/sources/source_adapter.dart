import '../models/work.dart';
import 'unified_source_models.dart';

abstract class UnifiedSourceAdapter {
  UnifiedSourceKind get kind;

  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  });

  Future<Work> loadDetail(UnifiedSourceRef ref);

  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref);

  Future<UnifiedSourceHealth> checkHealth();
}

/// Optional catalog metadata exposed by sources that can discover an exact or
/// provider-authoritative result count while paging their own site/API.
abstract interface class CatalogCountAwareSourceAdapter {
  int? knownTotalCount(String keyword);
}
