enum AudioExtensionAuthRequirement {
  none,
  optional,
  required;

  static AudioExtensionAuthRequirement parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      null || '' || 'none' => AudioExtensionAuthRequirement.none,
      'optional' => AudioExtensionAuthRequirement.optional,
      'required' => AudioExtensionAuthRequirement.required,
      _ => throw FormatException('Unsupported audio extension auth: $value'),
    };
  }

  String get wireValue => name;
}

enum AudioExtensionCapability {
  catalog,
  search,
  detail,
  playback,
  download,
  subtitles;

  static AudioExtensionCapability parse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final capability in values) {
      if (capability.name == normalized) return capability;
    }
    throw FormatException('Unsupported audio extension capability: $value');
  }
}

class AudioExtensionManifest {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String type;
  final AudioExtensionAuthRequirement auth;
  final Set<AudioExtensionCapability> capabilities;
  final List<String> languages;
  final String? homepage;
  final String? minHiraukanVersion;

  const AudioExtensionManifest({
    this.schemaVersion = currentSchemaVersion,
    required this.id,
    required this.name,
    required this.version,
    this.type = 'audio',
    this.auth = AudioExtensionAuthRequirement.none,
    this.capabilities = const {
      AudioExtensionCapability.catalog,
      AudioExtensionCapability.search,
      AudioExtensionCapability.detail,
      AudioExtensionCapability.playback,
    },
    this.languages = const [],
    this.homepage,
    this.minHiraukanVersion,
  });

  factory AudioExtensionManifest.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? currentSchemaVersion;
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported audio extension schemaVersion: $schemaVersion',
      );
    }

    final id = (json['id'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final version = (json['version'] as String? ?? '').trim();
    final type = (json['type'] as String? ?? 'audio').trim().toLowerCase();

    if (id.isEmpty || !RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(id)) {
      throw const FormatException(
        'Audio extension id must use lowercase letters, numbers, dot, dash, or underscore',
      );
    }
    if (name.isEmpty) {
      throw const FormatException('Audio extension name must not be empty');
    }
    if (version.isEmpty) {
      throw const FormatException('Audio extension version must not be empty');
    }
    if (type != 'audio') {
      throw FormatException('Unsupported extension type: $type');
    }

    final rawCapabilities =
        (json['capabilities'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => AudioExtensionCapability.parse(value.toString()))
            .toSet();

    final capabilities = rawCapabilities.isEmpty
        ? const {
            AudioExtensionCapability.catalog,
            AudioExtensionCapability.search,
            AudioExtensionCapability.detail,
            AudioExtensionCapability.playback,
          }
        : rawCapabilities;

    return AudioExtensionManifest(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      version: version,
      type: type,
      auth: AudioExtensionAuthRequirement.parse(json['auth'] as String?),
      capabilities: capabilities,
      languages: (json['languages'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      homepage: (json['homepage'] as String?)?.trim(),
      minHiraukanVersion: (json['minHiraukanVersion'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'version': version,
        'type': type,
        'auth': auth.wireValue,
        'capabilities': capabilities.map((value) => value.name).toList()..sort(),
        'languages': languages,
        if (homepage != null && homepage!.isNotEmpty) 'homepage': homepage,
        if (minHiraukanVersion != null && minHiraukanVersion!.isNotEmpty)
          'minHiraukanVersion': minHiraukanVersion,
      };
}
