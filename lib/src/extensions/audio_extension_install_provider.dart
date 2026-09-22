import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import 'audio_extension.dart';
import 'miyorare_audio_pack.dart';

const _installedAudioExtensionsKey = 'installed_audio_extensions_v1';
const _installedAudioExtensionsDefaultsVersionKey =
    'installed_audio_extensions_defaults_version';
const _installedAudioExtensionsDefaultsVersion = 2;
const _newAudioExtensionsV2 = <String>{
  'miyorare.audio.asmr_hentai_net',
  'miyorare.audio.japanese_asmr',
  'miyorare.audio.asmr18',
};
const _defaultInstalledAudioExtensions = <String>{
  'miyorare.audio.asmr_one',
  'miyorare.audio.hentai_asmr',
  'miyorare.audio.japanese_asmr',
  'miyorare.audio.asmr18',
  'miyorare.audio.ero_voice',
  'miyorare.audio.asmr_hentai_net',
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
      unawaited(
        StorageService.setSetting(
          _installedAudioExtensionsDefaultsVersionKey,
          _installedAudioExtensionsDefaultsVersion,
        ),
      );
      return Set<String>.from(_defaultInstalledAudioExtensions);
    }

    final installed = stored.map((value) => value.toString()).toSet();
    final defaultsVersion = StorageService.getSetting<int>(
          _installedAudioExtensionsDefaultsVersionKey,
        ) ??
        1;
    if (defaultsVersion < _installedAudioExtensionsDefaultsVersion) {
      installed.addAll(_newAudioExtensionsV2);
      unawaited(_persistInstalledIds(installed));
      unawaited(
        StorageService.setSetting(
          _installedAudioExtensionsDefaultsVersionKey,
          _installedAudioExtensionsDefaultsVersion,
        ),
      );
    }
    return installed;
  }

  Future<void> install(MiyorareAudioPackEntry entry) async {
    if (entry.deliveryKind != 'builtin') {
      throw StateError('Unsupported audio extension delivery');
    }
    final runtime = _bundled[entry.runtimeId];
    if (runtime == null) {
      throw StateError(
        'Hiraukan does not bundle audio runtime: ' + entry.runtimeId,
      );
    }
    _verifyCompatibility(entry, runtime);

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

  void _verifyCompatibility(
    MiyorareAudioPackEntry entry,
    AudioExtension runtime,
  ) {
    final expected = entry.manifest;
    final actual = runtime.manifest;
    if (actual.type != expected.type ||
        actual.version != expected.version ||
        actual.auth != expected.auth ||
        !actual.capabilities.containsAll(expected.capabilities)) {
      throw StateError(
        'Bundled audio runtime is incompatible with pack entry: ' +
            entry.runtimeId,
      );
    }
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
