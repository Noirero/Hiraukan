import '../sources/hentai_asmr_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';
import 'direct_source_audio_extension.dart';

AudioExtension createHentaiAsmrAudioExtension() {
  return AdapterBackedDirectAudioExtension(
    adapter: HentaiAsmrSourceAdapter(),
    manifest: const AudioExtensionManifest(
      id: 'miyorare.audio.hentai_asmr',
      name: 'HentaiASMR',
      version: '1.0.0',
      auth: AudioExtensionAuthRequirement.none,
      capabilities: {
        AudioExtensionCapability.catalog,
        AudioExtensionCapability.search,
        AudioExtensionCapability.detail,
        AudioExtensionCapability.playback,
        AudioExtensionCapability.download,
      },
      languages: ['ja'],
      homepage: HentaiAsmrSourceAdapter.baseUrl,
    ),
    refBuilder: (workId) {
      final id = workId.toUpperCase();
      return UnifiedSourceRef(
        source: UnifiedSourceKind.hentaiAsmr,
        localId: id,
        canonicalId: id.startsWith('RJ') ? id : null,
        detailUrl: HentaiAsmrSourceAdapter.baseUrl + '/' + id.toLowerCase() + '.html',
      );
    },
  );
}
