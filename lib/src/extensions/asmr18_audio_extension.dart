import '../sources/asmr18_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';
import 'direct_source_audio_extension.dart';

AudioExtension createAsmr18AudioExtension() {
  return AdapterBackedDirectAudioExtension(
    adapter: Asmr18SourceAdapter(),
    manifest: const AudioExtensionManifest(
      id: 'miyorare.audio.asmr18',
      name: 'ASMR+18',
      version: '1.0.0',
      auth: AudioExtensionAuthRequirement.none,
      capabilities: {
        AudioExtensionCapability.catalog,
        AudioExtensionCapability.search,
        AudioExtensionCapability.detail,
        AudioExtensionCapability.playback,
      },
      languages: ['ja'],
      homepage: Asmr18SourceAdapter.baseUrl,
    ),
    refBuilder: (workId) {
      final canonical = workId.toUpperCase();
      return UnifiedSourceRef(
        source: UnifiedSourceKind.asmr18,
        localId: workId,
        canonicalId: canonical.startsWith('RJ') ? canonical : null,
        detailUrl: Asmr18SourceAdapter.baseUrl + '/boys/' + canonical.toLowerCase() + '/',
      );
    },
  );
}
