import 'package:flutter/services.dart';

import 'storage_service.dart';

class FloatingLyricEnhancementService {
  FloatingLyricEnhancementService._();
  static final instance = FloatingLyricEnhancementService._();

  static const _channel = MethodChannel('com.kikoeru.flutter/floating_lyric');
  static const _prefix = 'floating_lyric_extra_';

  bool get shadowEnabled =>
      StorageService.getBool('${_prefix}shadow_enabled') ?? true;
  double get shadowBlur =>
      (StorageService.getInt('${_prefix}shadow_blur_x10') ?? 30) / 10;
  int get transparencyMode =>
      StorageService.getInt('${_prefix}transparency_mode') ?? 0;
  bool get showCloseButton =>
      StorageService.getBool('${_prefix}show_close') ?? false;
  String get fontFamily =>
      StorageService.getString('${_prefix}font_family') ?? '';
  int get fontWeight => StorageService.getInt('${_prefix}font_weight') ?? 6;

  Future<void> setShadowEnabled(bool value) async {
    await StorageService.setBool('${_prefix}shadow_enabled', value);
    await apply();
  }

  Future<void> setShadowBlur(double value) async {
    await StorageService.setInt('${_prefix}shadow_blur_x10', (value * 10).round());
    await apply();
  }

  Future<void> setTransparencyMode(int value) async {
    await StorageService.setInt(
      '${_prefix}transparency_mode',
      value.clamp(0, 2).toInt(),
    );
    await apply();
  }

  Future<void> setShowCloseButton(bool value) async {
    await StorageService.setBool('${_prefix}show_close', value);
    await apply();
  }

  Future<void> setFontFamily(String value) async {
    await StorageService.setString('${_prefix}font_family', value.trim());
    await apply();
  }

  Future<void> setFontWeight(int value) async {
    await StorageService.setInt(
      '${_prefix}font_weight',
      value.clamp(0, 8).toInt(),
    );
    await apply();
  }

  Future<bool> apply() async {
    try {
      final result = await _channel.invokeMethod<bool>('updateStyle', {
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'shadowEnabled': shadowEnabled,
        'shadowBlur': shadowBlur,
        'shadowColor': 0xCC000000,
        'transparencyMode': transparencyMode,
        'showCloseButton': showCloseButton,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
