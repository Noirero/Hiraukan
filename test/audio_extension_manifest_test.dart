import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension_manifest.dart';

void main() {
  group('AudioExtensionManifest', () {
    test('parses minimal anonymous audio manifest', () {
      final manifest = AudioExtensionManifest.fromJson({
        'schemaVersion': 1,
        'id': 'miyorare.audio.example',
        'name': 'Example Audio',
        'version': '1.0.0',
        'type': 'audio',
        'auth': 'none',
      });

      expect(manifest.id, 'miyorare.audio.example');
      expect(manifest.type, 'audio');
      expect(manifest.auth, AudioExtensionAuthRequirement.none);
      expect(
        manifest.capabilities,
        contains(AudioExtensionCapability.playback),
      );
    });

    test('supports optional authentication', () {
      final manifest = AudioExtensionManifest.fromJson({
        'id': 'miyorare.audio.optional',
        'name': 'Optional Auth',
        'version': '1.0.0',
        'auth': 'optional',
        'capabilities': ['search', 'detail', 'playback'],
      });

      expect(manifest.auth, AudioExtensionAuthRequirement.optional);
      expect(
        manifest.capabilities,
        containsAll([
          AudioExtensionCapability.search,
          AudioExtensionCapability.detail,
          AudioExtensionCapability.playback,
        ]),
      );
    });

    test('rejects non-audio media types', () {
      expect(
        () => AudioExtensionManifest.fromJson({
          'id': 'miyorare.audio.invalid',
          'name': 'Invalid',
          'version': '1.0.0',
          'type': 'manga',
        }),
        throwsFormatException,
      );
    });

    test('rejects unstable uppercase ids', () {
      expect(
        () => AudioExtensionManifest.fromJson({
          'id': 'Miyorare.Audio.Invalid',
          'name': 'Invalid',
          'version': '1.0.0',
        }),
        throwsFormatException,
      );
    });
  });
}
