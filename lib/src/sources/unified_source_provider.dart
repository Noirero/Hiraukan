import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'asmr_one_source_adapter.dart';
import 'ero_voice_source_adapter.dart';
import 'hentai_asmr_source_adapter.dart';
import 'unified_source_registry.dart';
import 'unified_source_service.dart';

final unifiedSourceServiceProvider = Provider<UnifiedSourceService>((ref) {
  final kikoeru = ref.watch(kikoeruApiServiceProvider);
  return UnifiedSourceService(
    adapters: [
      AsmrOneSourceAdapter(kikoeru),
      HentaiAsmrSourceAdapter(),
      EroVoiceSourceAdapter(),
    ],
    registry: UnifiedSourceRegistry.instance,
  );
});
