import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'audio_extension.dart';
import 'miyorare_audio_pack.dart';

const _installedAudioExtensionsKey = 'installed_audio_extensions_v1';
const _defaultInstalledAudioExtensions = <String>{
  'miyorare.audio.asmr_one',
};

class AudioExtensionInstallState {
  final Set<String> installedIds;

  const AudioExtensionInstallState(this.installedIds);

  bool isInstalled(String id) => installedIds.contains(id);
}

class AudioExtensionInstallController
    extends StateNotifier<AudioExtensionInstallState> {
  final Map<String, AudioExtension> _bundled;

  AudioExtensionInstallController(Iterable<AudioExtension> bundled)
      : _bundled = {
          for (final extension in bundled) extension.manifest.id: extension,
        },
        super(AudioExtensionInstallState(_loadInstalledIds()));

  static Set<String> _loadInstalledIds() {
    final stored = StorageService.getSetting<List<dynamic>>(
      _installedAudioExtensionsKey,
    );
    if (stored == null) {
      return Set<String>.from(_defaultInstalledAudioExtensions);
    }
    return stored.map((value) => value.toString()).toSet();
  }

  Future<void> install(MiyorareAudioPackEntry entry) async {
    if (entry.deliveryKind != 'builtin') {
      throw StateError('Unsupported audio extension delivery');
    }
    if (!_bundled.containsKey(entry.runtimeId)) {
      throw StateError(
        'Hiraukan does not bundle audio runtime: ' + entry.runtimeId,
      );
    }

    final next = Set<String>.from(state.installedIds)..add(entry.runtimeId);
    await _save(next);
  }

  Future<void> remove(String extensionId) async {
    final next = Set<String>.from(state.installedIds)..remove(extensionId);
    await _save(next);
  }

  Future<void> restoreDefaults() async {
    await _save(Set<String>.from(_defaultInstalledAudioExtensions));
  }

  Future<void> _save(Set<String> values) async {
    final sorted = values.toList()..sort();
    await StorageService.setSetting(_installedAudioExtensionsKey, sorted);
    state = AudioExtensionInstallState(Set.unmodifiable(values));
  }
}
