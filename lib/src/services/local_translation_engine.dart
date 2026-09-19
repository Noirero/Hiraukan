enum LocalModelState {
  notInstalled,
  downloading,
  verifying,
  ready,
  updateAvailable,
  corrupt,
  incompatible,
  failed,
}

class LocalTranslationCapabilities {
  final bool supportsNativeContextWindow;
  final bool supportsNativeGlossaryHints;
  final int maxContextSegments;

  const LocalTranslationCapabilities({
    required this.supportsNativeContextWindow,
    required this.supportsNativeGlossaryHints,
    required this.maxContextSegments,
  });
}

class LocalTranslationModelStatus {
  final LocalModelState state;
  final String engineId;
  final String engineVersion;
  final bool sourceModelInstalled;
  final bool targetModelInstalled;
  final String? message;

  const LocalTranslationModelStatus({
    required this.state,
    required this.engineId,
    required this.engineVersion,
    required this.sourceModelInstalled,
    required this.targetModelInstalled,
    this.message,
  });

  bool get isReady =>
      state == LocalModelState.ready &&
      sourceModelInstalled &&
      targetModelInstalled;
}

abstract interface class LocalTranslationEngine {
  String get id;
  String get version;
  String get displayName;
  LocalTranslationCapabilities get capabilities;

  Future<LocalTranslationModelStatus> getModelStatus();

  Future<LocalTranslationModelStatus> downloadModels({
    bool wifiOnly = true,
  });

  Future<LocalTranslationModelStatus> deleteModels();

  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  });
}

class LocalTranslationModelNotInstalledException implements Exception {
  const LocalTranslationModelNotInstalledException();

  @override
  String toString() => 'Local translation model is not installed';
}
