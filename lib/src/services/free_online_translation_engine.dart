import 'package:translator/translator.dart';

import 'local_translation_engine.dart';

/// Online Japanese -> Indonesian translation without an API key or bundled model.
///
/// This uses the same lightweight Google Translate web client approach already
/// used by KikoFlu/Hiraukan's legacy Google provider. It requires internet
/// access and intentionally has no paid/API fallback.
class FreeOnlineTranslationEngine implements LocalTranslationEngine {
  FreeOnlineTranslationEngine._();

  static final FreeOnlineTranslationEngine instance =
      FreeOnlineTranslationEngine._();

  final GoogleTranslator _translator = GoogleTranslator();

  @override
  String get id => 'google_web_no_key';

  @override
  String get version => 'translator-1.0.0-v1';

  @override
  String get displayName => 'Gratis Online (Tanpa API)';

  LocalTranslationModelStatus get _readyStatus =>
      LocalTranslationModelStatus(
        state: LocalModelState.ready,
        engineId: id,
        engineVersion: version,
        sourceModelInstalled: true,
        targetModelInstalled: true,
        message: 'Online; tidak membutuhkan model lokal.',
      );

  @override
  Future<LocalTranslationModelStatus> getModelStatus() async => _readyStatus;

  @override
  Future<LocalTranslationModelStatus> downloadModels({
    bool wifiOnly = true,
  }) async =>
      _readyStatus;

  @override
  Future<LocalTranslationModelStatus> deleteModels() async => _readyStatus;

  @override
  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  }) async {
    if (text.trim().isEmpty) return text;
    if (sourceLanguage != 'ja' || targetLanguage != 'id') {
      throw ArgumentError(
        'Free Online translation currently supports ja -> id only.',
      );
    }

    final result = await _translator.translate(
      text,
      from: sourceLanguage,
      to: targetLanguage,
    );
    final translated = result.text.trim();
    return translated.isEmpty ? text : translated;
  }
}
