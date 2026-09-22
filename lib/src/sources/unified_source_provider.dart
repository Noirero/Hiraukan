import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
import '../providers/auth_provider.dart';
import '../services/miyorare_audio_catalog_service.dart';
import 'asmr_one_source_adapter.dart';
import 'asmr18_source_adapter.dart';
import 'asmr_hentai_net_source_adapter.dart';
import 'ero_voice_source_adapter.dart';
import 'hentai_asmr_source_adapter.dart';
import 'japanese_asmr_source_adapter.dart';
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
  final installed = ref.watch(audioExtensionInstallProvider).installedIds;
  final remoteCatalog = ref.watch(miyorareAudioCatalogProvider).valueOrNull;
  final allowed = remoteCatalog == null
      ? MiyorareAudioCatalogService.lastKnownGoodExtensionIds()
      : remoteCatalog.pack.extensions
          .map((entry) => entry.runtimeId)
          .toSet();

  bool enabled(String id) =>
      installed.contains(id) && (allowed == null || allowed.contains(id));

  return _CatalogAwareUnifiedSourceService(
    adapters: [
      if (enabled('miyorare.audio.asmr_one')) AsmrOneSourceAdapter(kikoeru),
      if (enabled('miyorare.audio.hentai_asmr')) HentaiAsmrSourceAdapter(),
      if (enabled('miyorare.audio.japanese_asmr')) JapaneseAsmrSourceAdapter(),
      if (enabled('miyorare.audio.asmr18')) Asmr18SourceAdapter(),
      if (enabled('miyorare.audio.ero_voice')) EroVoiceSourceAdapter(),
      if (enabled('miyorare.audio.asmr_hentai_net'))
        AsmrHentaiNetSourceAdapter(),
    ],
    registry: UnifiedSourceRegistry.instance,
  );
});
