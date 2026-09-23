import '../sources/asmr_hentai_net_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';
import 'direct_source_audio_extension.dart';

AudioExtension createAsmrHentaiNetAudioExtension() {
  return AdapterBackedDirectAudioExtension(
    adapter: AsmrHentaiNetSourceAdapter(),
    manifest: const AudioExtensionManifest(
      id: 'miyorare.audio.asmr_hentai_net',
      name: 'ASMR Hentai',
      version: '1.0.0',
      auth: AudioExtensionAuthRequirement.none,
      capabilities: {
        AudioExtensionCapability.catalog,
        AudioExtensionCapability.search,
        AudioExtensionCapability.detail,
        AudioExtensionCapability.playback,
        AudioExtensionCapability.subtitles,
      },
      languages: ['ja'],
      homepage: AsmrHentaiNetSourceAdapter.baseUrl,
    ),
    refBuilder: (workId) {
      final id = workId.toUpperCase();
      return UnifiedSourceRef(
        source: UnifiedSourceKind.asmrHentaiNet,
        localId: id,
        canonicalId: id.startsWith('RJ') ? id : null,
        detailUrl: AsmrHentaiNetSourceAdapter.baseUrl + '/' + id,
      );
    },
  );
}
