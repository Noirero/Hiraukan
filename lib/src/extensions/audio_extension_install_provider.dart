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
  final Future<void> Function(Set<String>) _persist;

  AudioExtensionInstallController(
    Iterable<AudioExtension> bundled, {
    Set<String>? initialInstalled,
    Future<void> Function(Set<String>)? persist,
  })  : _bundled = {
          for (final extension in bundled) extension.manifest.id: extension,
        },
        _persist = persist ?? _persistInstalledIds,
        super(
          AudioExtensionInstallState(
            initialInstalled == null
                ? _loadInstalledIds()
                : Set.unmodifiable(initialInstalled),
          ),
        );

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

  static Future<void> _persistInstalledIds(Set<String> values) async {
    final sorted = values.toList()..sort();
    await StorageService.setSetting(_installedAudioExtensionsKey, sorted);
  }

  Future<void> _save(Set<String> values) async {
    await _persist(values);
    state = AudioExtensionInstallState(Set.unmodifiable(values));
  }
}
