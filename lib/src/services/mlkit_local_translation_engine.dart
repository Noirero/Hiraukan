import 'package:flutter/services.dart';

import 'local_translation_engine.dart';

class MlKitLocalTranslationEngine implements LocalTranslationEngine {
  MlKitLocalTranslationEngine._();

  static final MlKitLocalTranslationEngine instance =
      MlKitLocalTranslationEngine._();

  static const MethodChannel _channel =
      MethodChannel('com.noirero.hiraukan/local_translation');

  @override
  String get id => 'mlkit_translation';

  @override
  String get version => '17.0.3';

  @override
  String get displayName => 'Local Lite (ML Kit)';

  @override
  Future<LocalTranslationModelStatus> getModelStatus() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('getModelStatus');
    return _statusFromMap(raw);
  }

  @override
  Future<LocalTranslationModelStatus> downloadModels({
    bool wifiOnly = true,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'downloadModels',
      {'wifiOnly': wifiOnly},
    );
    return _statusFromMap(raw);
  }

  @override
  Future<LocalTranslationModelStatus> deleteModels() async {
    final raw =
        await _channel.invokeMapMethod<String, dynamic>('deleteModels');
    return _statusFromMap(raw);
  }

  @override
  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  }) async {
    if (text.trim().isEmpty) return text;
    try {
      final translated = await _channel.invokeMethod<String>(
        'translate',
        {
          'text': text,
          'sourceLanguage': sourceLanguage,
          'targetLanguage': targetLanguage,
        },
      );
      return translated ?? text;
    } on PlatformException catch (error) {
      if (error.code == 'MODEL_NOT_INSTALLED') {
        throw const LocalTranslationModelNotInstalledException();
      }
      rethrow;
    }
  }

  LocalTranslationModelStatus _statusFromMap(Map<String, dynamic>? raw) {
    final stateName = raw?['state']?.toString() ?? 'failed';
    final state = LocalModelState.values.firstWhere(
      (value) => value.name == stateName,
      orElse: () => LocalModelState.failed,
    );
    return LocalTranslationModelStatus(
      state: state,
      engineId: raw?['engineId']?.toString() ?? id,
      engineVersion: raw?['engineVersion']?.toString() ?? version,
      sourceModelInstalled: raw?['sourceModelInstalled'] == true,
      targetModelInstalled: raw?['targetModelInstalled'] == true,
      message: raw?['message']?.toString(),
    );
  }
}
