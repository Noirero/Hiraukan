import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_install_provider.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_manifest.dart';
import 'package:kikoeru_flutter/src/extensions/miyorare_audio_pack.dart';

void main() {
  const packJson = {
    'schemaVersion': 1,
    'packId': 'miyorare-audio',
    'displayName': 'Miyorare Audio',
    'mediaType': 'audio',
    'consumer': {
      'application': 'Hiraukan',
      'repository': 'Noirero/Hiraukan',
      'extensionSchemaVersion': 1,
    },
    'extensions': [
      {
        'id': 'miyorare.audio.asmr_one',
        'name': 'ASMR.one',
        'version': '1.0.0',
        'type': 'audio',
        'auth': 'optional',
        'languages': ['ja'],
        'capabilities': ['catalog', 'search', 'detail', 'playback'],
        'delivery': {
          'kind': 'builtin',
          'runtimeId': 'miyorare.audio.asmr_one',
        },
      },
    ],
  };

  group('MiyorareAudioPack', () {
    test('parses schema-v1 builtin audio extension entries', () {
      final pack = MiyorareAudioPack.fromJson(packJson);

      expect(pack.packId, 'miyorare-audio');
      expect(pack.extensions, hasLength(1));
      expect(
        pack.extensions.single.manifest.auth,
        AudioExtensionAuthRequirement.optional,
      );
      expect(pack.extensions.single.runtimeId, 'miyorare.audio.asmr_one');
    });

    test('rejects downloadable executable delivery in schema v1', () {
      final json = Map<String, dynamic>.from(packJson);
      final entry = Map<String, dynamic>.from(
        (packJson['extensions'] as List).single as Map,
      );
      entry['delivery'] = {
        'kind': 'download',
        'runtimeId': 'miyorare.audio.asmr_one',
      };
      json['extensions'] = [entry];

      expect(
        () => MiyorareAudioPack.fromJson(json),
        throwsFormatException,
      );
    });
  });

  group('AudioExtensionInstallController', () {
    test('install and remove gate a bundled runtime', () async {
      final extension = _FakeExtension('miyorare.audio.asmr_one');
      Set<String>? persisted;
      final controller = AudioExtensionInstallController(
        [extension],
        initialInstalled: const {},
        persist: (ids) async => persisted = Set<String>.from(ids),
      );
      final entry = MiyorareAudioPack.fromJson(packJson).extensions.single;

      expect(controller.state.isInstalled(extension.manifest.id), isFalse);

      await controller.install(entry);
      expect(controller.state.isInstalled(extension.manifest.id), isTrue);
      expect(persisted, contains(extension.manifest.id));

      await controller.remove(extension.manifest.id);
      expect(controller.state.isInstalled(extension.manifest.id), isFalse);
      expect(persisted, isNot(contains(extension.manifest.id)));
    });

    test('refuses pack entries without a bundled Hiraukan runtime', () async {
      final controller = AudioExtensionInstallController(
        const [],
        initialInstalled: const {},
        persist: (_) async {},
      );
      final entry = MiyorareAudioPack.fromJson(packJson).extensions.single;

      expect(
        () => controller.install(entry),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _FakeExtension implements AudioExtension {
  _FakeExtension(this.id);

  final String id;

  @override
  AudioExtensionManifest get manifest => AudioExtensionManifest(
        id: id,
        name: 'Fake',
        version: '1.0.0',
      );

  @override
  Future<AudioExtensionPage> browse({
    required int page,
    required int pageSize,
  }) async =>
      const AudioExtensionPage(items: [], hasMore: false);

  @override
  Future<AudioExtensionPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async =>
      const AudioExtensionPage(items: [], hasMore: false);

  @override
  Future<AudioExtensionWork> getDetail(String workId) async {
    return AudioExtensionWork(id: workId, title: 'Fake');
  }

  @override
  Future<List<AudioExtensionTrack>> getTracks(String workId) async => const [];

  @override
  Future<AudioPlaybackRequest> resolvePlayback({
    required String workId,
    required String trackId,
  }) async {
    return AudioPlaybackRequest(uri: Uri.parse('https://example.test/a.mp3'));
  }

  @override
  Future<AudioExtensionHealth> checkHealth() async {
    return AudioExtensionHealth.healthy;
  }
}
