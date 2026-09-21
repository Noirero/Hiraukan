import 'storage_service.dart';

class SubtitleLanguageOption {
  final String code;
  final String label;

  const SubtitleLanguageOption(this.code, this.label);
}

/// Shared language routing for online ASR + subtitle translation.
///
/// Values are lightweight strings only. No language model is bundled or
/// downloaded by this class.
class SubtitleLanguageSettings {
  SubtitleLanguageSettings._();

  static final SubtitleLanguageSettings instance =
      SubtitleLanguageSettings._();

  static const sourceLanguageKey = 'subtitle_pipeline_source_language';
  static const targetLanguageKey = 'subtitle_pipeline_target_language';
  static const asrEngineKey = 'subtitle_pipeline_asr_engine';

  static const commonLanguages = <SubtitleLanguageOption>[
    SubtitleLanguageOption('id', 'Indonesia'),
    SubtitleLanguageOption('en', 'English'),
    SubtitleLanguageOption('ja', 'Japanese'),
    SubtitleLanguageOption('ko', 'Korean'),
    SubtitleLanguageOption('zh-cn', 'Chinese · Simplified'),
    SubtitleLanguageOption('zh-tw', 'Chinese · Traditional'),
    SubtitleLanguageOption('es', 'Spanish'),
    SubtitleLanguageOption('fr', 'French'),
    SubtitleLanguageOption('de', 'German'),
    SubtitleLanguageOption('pt', 'Portuguese'),
    SubtitleLanguageOption('ru', 'Russian'),
    SubtitleLanguageOption('th', 'Thai'),
    SubtitleLanguageOption('vi', 'Vietnamese'),
  ];

  String get sourceLanguage =>
      _normalize(StorageService.getString(sourceLanguageKey) ?? 'auto',
          allowAuto: true);

  String get targetLanguage =>
      _normalize(StorageService.getString(targetLanguageKey) ?? 'id',
          allowAuto: false);

  String get asrEngine {
    final value = StorageService.getString(asrEngineKey)?.trim();
    return value == null || value.isEmpty ? 'auto' : value;
  }

  Future<void> setSourceLanguage(String value) {
    return StorageService.setString(
      sourceLanguageKey,
      _normalize(value, allowAuto: true),
    );
  }

  Future<void> setTargetLanguage(String value) {
    return StorageService.setString(
      targetLanguageKey,
      _normalize(value, allowAuto: false),
    );
  }

  Future<void> setAsrEngine(String value) {
    final normalized = value.trim();
    return StorageService.setString(
      asrEngineKey,
      normalized.isEmpty ? 'auto' : normalized,
    );
  }

  static String labelFor(String code) {
    if (code == 'auto') return 'Auto Detect';
    for (final language in commonLanguages) {
      if (language.code == code) return language.label;
    }
    return code;
  }

  static String _normalize(String value, {required bool allowAuto}) {
    var normalized = value.trim().toLowerCase().replaceAll('_', '-');
    if (normalized.isEmpty) return allowAuto ? 'auto' : 'id';
    if (!allowAuto && normalized == 'auto') return 'id';
    if (normalized == 'zh-hans' || normalized == 'zh-cn') return 'zh-cn';
    if (normalized == 'zh-hant' || normalized == 'zh-tw') return 'zh-tw';
    return normalized;
  }
}
