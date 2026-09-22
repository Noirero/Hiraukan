import 'audio_extension_manifest.dart';

class MiyorareAudioPack {
  final int schemaVersion;
  final String packId;
  final String displayName;
  final String mediaType;
  final int extensionSchemaVersion;
  final List<MiyorareAudioPackEntry> extensions;

  const MiyorareAudioPack({
    required this.schemaVersion,
    required this.packId,
    required this.displayName,
    required this.mediaType,
    required this.extensionSchemaVersion,
    required this.extensions,
  });

  factory MiyorareAudioPack.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 0;
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported Miyorare audio pack schemaVersion: $schemaVersion',
      );
    }
    if (json['packId'] != 'miyorare-audio') {
      throw const FormatException('Unexpected Miyorare audio pack id');
    }
    if (json['mediaType'] != 'audio') {
      throw const FormatException('Miyorare audio pack mediaType must be audio');
    }

    final consumer = json['consumer'];
    if (consumer is! Map) {
      throw const FormatException('Miyorare audio pack consumer is required');
    }
    if (consumer['repository'] != 'Noirero/Hiraukan') {
      throw const FormatException(
        'Miyorare audio pack is not intended for Hiraukan',
      );
    }
    final extensionSchemaVersion =
        consumer['extensionSchemaVersion'] as int? ?? 0;
    if (extensionSchemaVersion != AudioExtensionManifest.currentSchemaVersion) {
      throw FormatException(
        'Unsupported audio extension schema: $extensionSchemaVersion',
      );
    }

    final rawExtensions = json['extensions'];
    if (rawExtensions is! List || rawExtensions.isEmpty) {
      throw const FormatException(
        'Miyorare audio pack must contain extensions',
      );
    }

    final extensions = rawExtensions
        .map(
          (value) => MiyorareAudioPackEntry.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);

    final ids = extensions.map((entry) => entry.manifest.id).toSet();
    if (ids.length != extensions.length) {
      throw const FormatException(
        'Miyorare audio pack contains duplicate extension ids',
      );
    }

    return MiyorareAudioPack(
      schemaVersion: schemaVersion,
      packId: 'miyorare-audio',
      displayName: (json['displayName'] as String? ?? 'Miyorare Audio').trim(),
      mediaType: 'audio',
      extensionSchemaVersion: extensionSchemaVersion,
      extensions: extensions,
    );
  }
}

class MiyorareAudioPackEntry {
  final AudioExtensionManifest manifest;
  final String deliveryKind;
  final String runtimeId;

  const MiyorareAudioPackEntry({
    required this.manifest,
    required this.deliveryKind,
    required this.runtimeId,
  });

  factory MiyorareAudioPackEntry.fromJson(Map<String, dynamic> json) {
    final manifest = AudioExtensionManifest.fromJson(json);
    final delivery = json['delivery'];
    if (delivery is! Map) {
      throw FormatException(
        'Audio extension ' + manifest.id + ' is missing delivery metadata',
      );
    }

    final kind = delivery['kind']?.toString() ?? '';
    final runtimeId = delivery['runtimeId']?.toString() ?? '';
    if (kind != 'builtin') {
      throw FormatException(
        'Audio pack schema v1 only supports builtin delivery',
      );
    }
    if (runtimeId != manifest.id) {
      throw FormatException(
        'Audio extension runtimeId must match its extension id',
      );
    }

    return MiyorareAudioPackEntry(
      manifest: manifest,
      deliveryKind: kind,
      runtimeId: runtimeId,
    );
  }
}
