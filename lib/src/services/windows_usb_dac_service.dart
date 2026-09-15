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
/// existing passthrough setting. The actual route is consumed by `_configureMpv`
/// before media_kit initializes on the next app launch.
class WindowsUsbDacService {
  WindowsUsbDacService._();
  static final instance = WindowsUsbDacService._();

  static const enabledKey = 'windows_usb_dac_enabled';
  static const deviceIdKey = 'windows_usb_dac_device_id';
  static const deviceNameKey = 'windows_usb_dac_device_name';

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

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
  }

  Future<void> selectDevice(WindowsAudioDevice? device) async {
    final prefs = await SharedPreferences.getInstance();
    if (device == null) {
      await prefs.remove(deviceIdKey);
      await prefs.remove(deviceNameKey);
      return;
    }
    await prefs.setString(deviceIdKey, device.id);
    await prefs.setString(deviceNameKey, device.name);
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
