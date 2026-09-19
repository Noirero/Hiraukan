abstract interface class TranslationEngine {
  String get id;
  String get version;
  String get displayName;

  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  });
}
