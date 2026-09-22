import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/kikoeru_api_service.dart' hide kikoeruApiServiceProvider;
import '../services/miyorare_audio_catalog_service.dart';
import 'asmr_one_audio_extension.dart';
import 'audio_extension.dart';
import 'ero_voice_audio_extension.dart';
import 'hentai_asmr_audio_extension.dart';
import 'audio_extension_install_provider.dart';
import 'audio_extension_registry.dart';

final bundledAudioExtensionsProvider = Provider<List<AudioExtension>>((ref) {
  final api = ref.watch(kikoeruApiServiceProvider);
  final auth = ref.watch(authProvider);

  return [
    AsmrOneAudioExtension(
      api: api,
      host: () => auth.host ?? KikoeruApiService.remoteHost,
      token: () => auth.token ?? '',
    ),
    createHentaiAsmrAudioExtension(),
    createEroVoiceAudioExtension(),
  ];
});

final audioExtensionInstallProvider = StateNotifierProvider<
    AudioExtensionInstallController, AudioExtensionInstallState>((ref) {
  return AudioExtensionInstallController(
    ref.watch(bundledAudioExtensionsProvider),
  );
});

final miyorareAudioCatalogServiceProvider =
    Provider<MiyorareAudioCatalogService>((ref) {
  return MiyorareAudioCatalogService();
});

final miyorareAudioCatalogProvider =
    FutureProvider<MiyorareAudioCatalogSnapshot?>((ref) async {
  return ref.read(miyorareAudioCatalogServiceProvider).loadLatest();
});


final audioExtensionRegistryProvider = Provider<AudioExtensionRegistry>((ref) {
  final bundled = ref.watch(bundledAudioExtensionsProvider);
  final installed = ref.watch(audioExtensionInstallProvider).installedIds;
  final remoteCatalog = ref.watch(miyorareAudioCatalogProvider).valueOrNull;
  final allowed = remoteCatalog == null
      ? MiyorareAudioCatalogService.lastKnownGoodExtensionIds()
      : remoteCatalog.pack.extensions
          .map((entry) => entry.runtimeId)
          .toSet();

  return AudioExtensionRegistry(
    bundled.where(
      (extension) =>
          installed.contains(extension.manifest.id) &&
          (allowed == null || allowed.contains(extension.manifest.id)),
    ),
  );
});
