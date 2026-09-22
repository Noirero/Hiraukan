import '../sources/japanese_asmr_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';
import 'direct_source_audio_extension.dart';

AudioExtension createJapaneseAsmrAudioExtension() {
  return AdapterBackedDirectAudioExtension(
    adapter: JapaneseAsmrSourceAdapter(),
    manifest: const AudioExtensionManifest(
      id: 'miyorare.audio.japanese_asmr',
      name: 'JapaneseASMR',
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
      homepage: JapaneseAsmrSourceAdapter.baseUrl,
    ),
    refBuilder: (workId) => UnifiedSourceRef(
      source: UnifiedSourceKind.japaneseAsmr,
      localId: workId,
      canonicalId: workId.toUpperCase().startsWith('RJ') ? workId.toUpperCase() : null,
      detailUrl: JapaneseAsmrSourceAdapter.baseUrl + '/' + workId + '/',
    ),
  );
}
