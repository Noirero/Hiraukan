import 'storage_service.dart';

/// Persistent opt-in settings for KikoFlu-derived features.
/// Defaults are deliberately conservative so existing Hiraukan playback,
/// downloads, and Unified Sources behavior remains unchanged after upgrade.
class KikoFluFeatureSettings {
  KikoFluFeatureSettings._();
  static final instance = KikoFluFeatureSettings._();

  static const _prefix = 'hiraukan_kikoflu_';

  bool get autoConvertWav =>
      StorageService.getBool('${_prefix}auto_convert_wav') ?? false;
  String get conversionFormat =>
      StorageService.getString('${_prefix}conversion_format') ?? 'flac';

  bool get aiTranscriptionEnabled =>
      StorageService.getBool('${_prefix}ai_transcription') ?? false;
  bool get autoAsrTranslateFallback =>
      StorageService.getBool('${_prefix}auto_asr_translate_fallback') ?? false;
  String get asrProfile {
    final value = StorageService.getString('${_prefix}asr_profile') ?? 'auto';
    return const {'auto', 'fast', 'highQuality', 'compatibility'}.contains(value)
        ? value
        : 'auto';
  }
  String get whisperModel =>
      StorageService.getString('${_prefix}whisper_model') ?? 'base';
  int get whisperThreads =>
      StorageService.getInt('${_prefix}whisper_threads') ?? 4;

  bool get notificationsEnabled =>
      StorageService.getBool('${_prefix}notifications') ?? false;
  bool get fcmEnabled => StorageService.getBool('${_prefix}fcm') ?? false;

  // KikoFlu's concrete Hi-Res implementation is Windows WASAPI-specific.
  // The Android-only integration must never report this setting as enabled
  // until Hiraukan gains a real Android native output backend.
  bool get hiResEnabled => false;
  bool get autoHiRes => false;

  Future<void> setAutoConvertWav(bool value) =>
      StorageService.setBool('${_prefix}auto_convert_wav', value);
  Future<void> setConversionFormat(String value) =>
      StorageService.setString('${_prefix}conversion_format', value);

  Future<void> setAiTranscriptionEnabled(bool value) =>
      StorageService.setBool('${_prefix}ai_transcription', value);
  Future<void> setAutoAsrTranslateFallback(bool value) =>
      StorageService.setBool('${_prefix}auto_asr_translate_fallback', value);
  Future<void> setAsrProfile(String value) {
    final safe =
        const {'auto', 'fast', 'highQuality', 'compatibility'}.contains(value)
            ? value
            : 'auto';
    return StorageService.setString('${_prefix}asr_profile', safe);
  }
  Future<void> setWhisperModel(String value) =>
      StorageService.setString('${_prefix}whisper_model', value);
  Future<void> setWhisperThreads(int value) => StorageService.setInt(
        '${_prefix}whisper_threads',
        value.clamp(1, 16).toInt(),
      );

  Future<void> setNotificationsEnabled(bool value) =>
      StorageService.setBool('${_prefix}notifications', value);
  Future<void> setFcmEnabled(bool value) =>
      StorageService.setBool('${_prefix}fcm', value);

  Future<void> setHiResEnabled(bool value) =>
      StorageService.setBool('${_prefix}hi_res', false);
  Future<void> setAutoHiRes(bool value) =>
      StorageService.setBool('${_prefix}auto_hi_res', false);
}
