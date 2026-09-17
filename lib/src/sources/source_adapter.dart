import '../models/work.dart';
import 'unified_source_models.dart';

abstract class UnifiedSourceAdapter {
  UnifiedSourceKind get kind;

  /// Static capabilities are intentionally separate from runtime health.
  /// A source can be healthy for catalog/detail/download while intentionally
  /// not participating in playback resolution.
  SourceCapabilities get capabilities => kind.capabilities;

  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  });

  Future<Work> loadDetail(UnifiedSourceRef ref);

  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref);

  Future<UnifiedSourceHealth> checkHealth();
}
