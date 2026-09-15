import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'windows_audio_device_service.dart';

class WindowsUsbDacSettings {
  final bool enabled;
  final String? deviceId;
  final String? deviceName;

  const WindowsUsbDacSettings({
    required this.enabled,
    this.deviceId,
    this.deviceName,
  });

  bool get hasDevice => deviceId != null && deviceId!.isNotEmpty;
}

/// Persists the Windows WASAPI-exclusive target independently from Hiraukan's
/// existing passthrough setting. A tiny sidecar is consumed by the pinned
/// just_audio_media_kit adapter after Hiraukan writes its normal mpv.conf, so
/// Unified Sources and the existing desktop playback stack stay untouched.
class WindowsUsbDacService {
  WindowsUsbDacService._();
  static final instance = WindowsUsbDacService._();

  static const enabledKey = 'windows_usb_dac_enabled';
  static const deviceIdKey = 'windows_usb_dac_device_id';
  static const deviceNameKey = 'windows_usb_dac_device_name';
  static const _sidecarName = 'hiraukan_wasapi.json';

  bool get isSupported => Platform.isWindows;

  Future<WindowsUsbDacSettings> load() async {
    if (!isSupported) {
      return const WindowsUsbDacSettings(enabled: false);
    }
    final prefs = await SharedPreferences.getInstance();
    return WindowsUsbDacSettings(
      enabled: prefs.getBool(enabledKey) ?? false,
      deviceId: prefs.getString(deviceIdKey),
      deviceName: prefs.getString(deviceNameKey),
    );
  }

  List<WindowsAudioDevice> get devices =>
      WindowsAudioDeviceService.instance.getOutputDevices();

  Future<File> _sidecarFile() async {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final configDir = Directory('${exeDir.path}${Platform.pathSeparator}portable_config');
    if (!await configDir.exists()) await configDir.create(recursive: true);
    return File('${configDir.path}${Platform.pathSeparator}$_sidecarName');
  }

  Future<void> _writeSidecar() async {
    if (!isSupported) return;
    final state = await load();
    final file = await _sidecarFile();
    await file.writeAsString(jsonEncode({
      'enabled': state.enabled,
      'deviceId': state.deviceId,
      'deviceName': state.deviceName,
    }));
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    await _writeSidecar();
  }

  Future<void> selectDevice(WindowsAudioDevice? device) async {
    final prefs = await SharedPreferences.getInstance();
    if (device == null) {
      await prefs.remove(deviceIdKey);
      await prefs.remove(deviceNameKey);
    } else {
      await prefs.setString(deviceIdKey, device.id);
      await prefs.setString(deviceNameKey, device.name);
    }
    await _writeSidecar();
  }

  Future<WindowsAudioDevice?> selectRecommendedIfNeeded() async {
    final current = await load();
    if (current.hasDevice) {
      for (final device in devices) {
        if (device.id == current.deviceId) return device;
      }
    }
    final outputs = devices;
    if (outputs.isEmpty) return null;
    final recommended = outputs.firstWhere(
      (device) => device.isLikelyUsbDac,
      orElse: () => outputs.firstWhere(
        (device) => device.isDefault,
        orElse: () => outputs.first,
      ),
    );
    await selectDevice(recommended);
    return recommended;
  }
}
