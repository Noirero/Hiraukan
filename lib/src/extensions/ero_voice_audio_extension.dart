import '../sources/ero_voice_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';
import 'direct_source_audio_extension.dart';

AudioExtension createEroVoiceAudioExtension() {
  return AdapterBackedDirectAudioExtension(
    adapter: EroVoiceSourceAdapter(),
    manifest: const AudioExtensionManifest(
      id: 'miyorare.audio.ero_voice',
      name: 'EroVoice',
      version: '1.0.0',
      auth: AudioExtensionAuthRequirement.none,
      capabilities: {
        AudioExtensionCapability.catalog,
        AudioExtensionCapability.search,
        AudioExtensionCapability.detail,
        AudioExtensionCapability.download,
      },
      languages: ['ja'],
    ),
    playbackEnabled: false,
    refBuilder: (workId) => UnifiedSourceRef(
      source: UnifiedSourceKind.eroVoice,
      localId: workId,
      detailUrl: workId,
    ),
  );
}
