import 'dart:io';

import 'package:flutter/services.dart';

import 'log_service.dart';

final _log = LogService.instance;

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

/// Optional native bridge for Hi-Res output. Missing platform channels are a
/// supported state: normal Hiraukan playback continues unchanged.
class HiResAudioService {
  HiResAudioService._();
  static final instance = HiResAudioService._();

  static const _channel = MethodChannel('kikoeru_flutter/hi_res_audio');
  bool _enabled = false;

  bool get enabled => _enabled;

  Future<HiResAudioCapabilities> capabilities() async {
    if (!(Platform.isAndroid || Platform.isWindows || Platform.isMacOS)) {
      return HiResAudioCapabilities.unsupported;
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceCapabilities',
      );
      if (data == null) return HiResAudioCapabilities.unsupported;
      return HiResAudioCapabilities(
        supported: data['supported'] == true,
        sampleRates: (data['sampleRates'] as List?)?.whereType<num>().map((v) => v.toInt()).toList() ?? const [],
        bitDepths: (data['bitDepths'] as List?)?.whereType<num>().map((v) => v.toInt()).toList() ?? const [],
        deviceName: data['deviceName']?.toString(),
      );
    } on MissingPluginException {
      return HiResAudioCapabilities.unsupported;
    } catch (error) {
      _log.warning('Hi-Res capability probe failed: $error', tag: 'HiRes');
      return HiResAudioCapabilities.unsupported;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        enabled ? 'enableHiRes' : 'disableHiRes',
      );
      _enabled = result ?? false;
      return _enabled;
    } on MissingPluginException {
      _enabled = false;
      return false;
    } catch (error) {
      _log.warning('Hi-Res toggle failed: $error', tag: 'HiRes');
      _enabled = false;
      return false;
    }
  }

  Future<bool> configureForTrack({
    required int sampleRate,
    required int bitDepth,
  }) async {
    if (!_enabled) return false;
    try {
      return await _channel.invokeMethod<bool>('configureFormat', {
            'sampleRate': sampleRate,
            'bitDepth': bitDepth,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
