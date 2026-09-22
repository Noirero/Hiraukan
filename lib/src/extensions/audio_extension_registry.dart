import 'audio_extension.dart';

class AudioExtensionRegistry {
  final Map<String, AudioExtension> _extensions;

  AudioExtensionRegistry(Iterable<AudioExtension> extensions)
      : _extensions = _buildRegistry(extensions);

  static Map<String, AudioExtension> _buildRegistry(
    Iterable<AudioExtension> extensions,
  ) {
    final result = <String, AudioExtension>{};
    for (final extension in extensions) {
      final id = extension.manifest.id;
      if (result.containsKey(id)) {
        throw StateError('Duplicate audio extension runtime id: ' + id);
      }
      result[id] = extension;
    }
    return result;
  }

  List<AudioExtension> get extensions =>
      _extensions.values.toList(growable: false);

  AudioExtension? byId(String id) => _extensions[id];

  bool contains(String id) => _extensions.containsKey(id);
}
