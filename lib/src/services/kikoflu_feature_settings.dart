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
  String get whisperModel =>
      StorageService.getString('${_prefix}whisper_model') ?? 'base';
  int get whisperThreads =>
      StorageService.getInt('${_prefix}whisper_threads') ?? 4;

  bool get notificationsEnabled =>
      StorageService.getBool('${_prefix}notifications') ?? true;
  bool get fcmEnabled => StorageService.getBool('${_prefix}fcm') ?? false;

  bool get hiResEnabled => StorageService.getBool('${_prefix}hi_res') ?? false;
  bool get autoHiRes => StorageService.getBool('${_prefix}auto_hi_res') ?? true;

  Future<void> setAutoConvertWav(bool value) =>
      StorageService.setBool('${_prefix}auto_convert_wav', value);
  Future<void> setConversionFormat(String value) =>
      StorageService.setString('${_prefix}conversion_format', value);

  Future<void> setAiTranscriptionEnabled(bool value) =>
      StorageService.setBool('${_prefix}ai_transcription', value);
  Future<void> setWhisperModel(String value) =>
      StorageService.setString('${_prefix}whisper_model', value);
  Future<void> setWhisperThreads(int value) =>
      StorageService.setInt('${_prefix}whisper_threads', value.clamp(1, 16));

  Future<void> setNotificationsEnabled(bool value) =>
      StorageService.setBool('${_prefix}notifications', value);
  Future<void> setFcmEnabled(bool value) =>
      StorageService.setBool('${_prefix}fcm', value);

  Future<void> setHiResEnabled(bool value) =>
      StorageService.setBool('${_prefix}hi_res', value);
  Future<void> setAutoHiRes(bool value) =>
      StorageService.setBool('${_prefix}auto_hi_res', value);
}
