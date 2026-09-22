import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
import '../providers/auth_provider.dart';
import '../services/miyorare_audio_catalog_service.dart';
import 'asmr_one_source_adapter.dart';
import 'ero_voice_source_adapter.dart';
import 'hentai_asmr_source_adapter.dart';
import 'unified_source_registry.dart';
import 'unified_source_service.dart';

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

  return UnifiedSourceService(
    adapters: [
      if (enabled('miyorare.audio.asmr_one')) AsmrOneSourceAdapter(kikoeru),
      if (enabled('miyorare.audio.hentai_asmr')) HentaiAsmrSourceAdapter(),
      if (enabled('miyorare.audio.ero_voice')) EroVoiceSourceAdapter(),
    ],
    registry: UnifiedSourceRegistry.instance,
  );
});
