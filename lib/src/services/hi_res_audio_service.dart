import 'dart:io';

import 'package:flutter/services.dart';

import 'log_service.dart';
import 'windows_usb_dac_service.dart';

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

/// Optional Hi-Res output bridge.
///
/// Windows uses Hiraukan's real media_kit/mpv path: active WASAPI devices are
/// enumerated natively and the chosen endpoint is routed in exclusive mode on
/// the next player initialization. Other platforms keep the existing optional
/// MethodChannel contract and safely fall back to normal playback when no
/// native implementation is present.
class HiResAudioService {
  HiResAudioService._();
  static final instance = HiResAudioService._();

  static const _channel = MethodChannel('kikoeru_flutter/hi_res_audio');
  bool _enabled = false;

  bool get enabled => _enabled;

  Future<HiResAudioCapabilities> capabilities() async {
    if (Platform.isWindows) {
      final service = WindowsUsbDacService.instance;
      final devices = service.devices;
      if (devices.isEmpty) return HiResAudioCapabilities.unsupported;
      final settings = await service.load();
      final matching = devices
          .where((device) => device.id == settings.deviceId)
          .toList(growable: false);
      final device = matching.isNotEmpty
          ? matching.first
          : devices.firstWhere(
              (candidate) => candidate.isDefault,
              orElse: () => devices.first,
            );
      _enabled = settings.enabled && settings.hasDevice;
      return HiResAudioCapabilities(
        supported: true,
        deviceName: device.name,
      );
    }

    if (!(Platform.isAndroid || Platform.isMacOS)) {
      return HiResAudioCapabilities.unsupported;
    }
    try {
      final data = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceCapabilities',
      );
      if (data == null) return HiResAudioCapabilities.unsupported;
      return HiResAudioCapabilities(
        supported: data['supported'] == true,
        sampleRates: (data['sampleRates'] as List?)
                ?.whereType<num>()
                .map((value) => value.toInt())
                .toList() ??
            const [],
        bitDepths: (data['bitDepths'] as List?)
                ?.whereType<num>()
                .map((value) => value.toInt())
                .toList() ??
            const [],
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
    if (Platform.isWindows) {
      final service = WindowsUsbDacService.instance;
      if (!enabled) {
        await service.setEnabled(false);
        _enabled = false;
        return false;
      }
      final device = await service.selectRecommendedIfNeeded();
      if (device == null) {
        _enabled = false;
        return false;
      }
      await service.setEnabled(true);
      _enabled = true;
      return true;
    }

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
    if (Platform.isWindows) {
      // WASAPI exclusive/mpv negotiates the stream format with the selected
      // endpoint. Do not report made-up sample-rate/bit-depth capabilities.
      return true;
    }
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
