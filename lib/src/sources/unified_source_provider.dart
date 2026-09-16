import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'asmr_one_source_adapter.dart';
import 'ero_voice_source_adapter.dart';
import 'hentai_asmr_source_adapter.dart';
import 'source_adapter.dart';
import 'unified_source_models.dart';
import 'unified_source_registry.dart';
import 'unified_source_service.dart';

class _CatalogAwareUnifiedSourceService extends UnifiedSourceService {
  const _CatalogAwareUnifiedSourceService({
    required super.adapters,
    required super.registry,
  });

  @override
  Future<UnifiedSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
    Set<UnifiedSourceKind>? enabledSources,
  }) async {
    final result = await super.search(
      keyword: keyword,
      page: page,
      pageSize: pageSize,
      enabledSources: enabledSources,
    );

    final enabled = enabledSources ?? UnifiedSourceKind.values.toSet();
    var totalCount = result.totalCount;
    for (final adapter in adapters) {
      if (!enabled.contains(adapter.kind) ||
          adapter is! CatalogCountAwareSourceAdapter) {
        continue;
      }
      final countAware = adapter as CatalogCountAwareSourceAdapter;
      final providerTotal = countAware.knownTotalCount(keyword);
      if (providerTotal != null && providerTotal > totalCount) {
        totalCount = providerTotal;
      }
    }

    if (totalCount == result.totalCount) return result;
    return UnifiedSearchPage(
      works: result.works,
      totalCount: totalCount,
      hasMore: result.hasMore,
      health: result.health,
    );
  }
}

final unifiedSourceServiceProvider = Provider<UnifiedSourceService>((ref) {
  final kikoeru = ref.watch(kikoeruApiServiceProvider);
  return _CatalogAwareUnifiedSourceService(
    adapters: [
      AsmrOneSourceAdapter(kikoeru),
      HentaiAsmrSourceAdapter(),
      EroVoiceSourceAdapter(),
    ],
    registry: UnifiedSourceRegistry.instance,
  );
});
