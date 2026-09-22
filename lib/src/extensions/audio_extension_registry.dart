import 'audio_extension.dart';

class AudioExtensionRegistry {
  final Map<String, AudioExtension> _extensions;

  AudioExtensionRegistry(Iterable<AudioExtension> extensions)
      : _extensions = {
          for (final extension in extensions) extension.manifest.id: extension,
        };

  List<AudioExtension> get extensions =>
      _extensions.values.toList(growable: false);

  AudioExtension? byId(String id) => _extensions[id];

  bool contains(String id) => _extensions.containsKey(id);
}
