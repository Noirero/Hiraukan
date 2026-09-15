class HiResAudioCapabilities {
  final bool supported;
  final List<int> sampleRates;
  final List<int> bitDepths;
  final String? deviceName;

  const HiResAudioCapabilities({
    required this.supported,
    this.sampleRates = const [],
    this.bitDepths = const [],
    this.deviceName,
  });

  static const unsupported = HiResAudioCapabilities(supported: false);
}

/// Placeholder capability surface kept so the settings screen can degrade
/// gracefully on the Android-only integration branch.
///
/// KikoFlu's concrete Hi-Res enhancement is Windows WASAPI/USB-DAC specific.
/// Hiraukan currently has no Android native output bridge that can reliably
/// force a requested sample rate/bit depth, so we deliberately report this as
/// unsupported rather than exposing a toggle that does nothing.
class HiResAudioService {
  HiResAudioService._();
  static final instance = HiResAudioService._();

  bool get enabled => false;

  Future<HiResAudioCapabilities> capabilities() async =>
      HiResAudioCapabilities.unsupported;

  Future<bool> setEnabled(bool enabled) async => false;

  Future<bool> configureForTrack({
    required int sampleRate,
    required int bitDepth,
  }) async =>
      false;
}
