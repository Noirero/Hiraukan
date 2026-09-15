import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'log_service.dart';
import 'storage_service.dart';

/// App lock for Hiraukan.
///
/// Inspired by KikoFlu's app-lock flow, but adapted to Hiraukan's existing
/// storage/lifecycle architecture. The lock supports a PIN, optional device
/// biometrics, and an automatic relock timeout after the app is backgrounded.
class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _enabledKey = 'hiraukan_app_lock_enabled';
  static const _pinHashKey = 'hiraukan_app_lock_pin_hash';
  static const _biometricKey = 'hiraukan_app_lock_biometric';
  static const _autoLockTimeoutKey = 'hiraukan_app_lock_timeout';
  static const _defaultTimeoutMinutes = 5;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  DateTime? _backgroundedAt;

  bool get isEnabled => StorageService.getBool(_enabledKey) ?? false;

  bool get isBiometricEnabled =>
      StorageService.getBool(_biometricKey) ?? false;

  bool get hasPin {
    final hash = StorageService.getString(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  int get autoLockTimeoutMinutes =>
      StorageService.getInt(_autoLockTimeoutKey) ?? _defaultTimeoutMinutes;

  void _notifyChanged() {
    revision.value++;
  }

  Future<bool> canUseBiometric() async {
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isWindows &&
        !Platform.isMacOS) {
      return false;
    }

    try {
      final supported = await _localAuth
          .isDeviceSupported()
          .timeout(const Duration(seconds: 3));
      if (!supported) return false;

      final canCheck = await _localAuth.canCheckBiometrics
          .timeout(const Duration(seconds: 3));
      if (!canCheck) return false;

      final available = await _localAuth
          .getAvailableBiometrics()
          .timeout(const Duration(seconds: 3));
      return available.isNotEmpty;
    } on TimeoutException {
      LogService.instance.warning(
        'Biometric capability check timed out',
        tag: 'AppLock',
      );
      return false;
    } catch (error) {
      LogService.instance.warning(
        'Biometric capability check failed: $error',
        tag: 'AppLock',
      );
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'Unlock Hiraukan',
  }) async {
    if (!await canUseBiometric()) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: Platform.isAndroid || Platform.isIOS,
        persistAcrossBackgrounding: Platform.isAndroid || Platform.isIOS,
      );
    } catch (error) {
      LogService.instance.warning(
        'Biometric authentication failed: $error',
        tag: 'AppLock',
      );
      return false;
    }
  }

  /// Hashes a PIN with repeated SHA-256 rounds.
  ///
  /// KikoFlu currently uses a small custom hash. Hiraukan deliberately uses a
  /// standard digest with repeated rounds instead, while keeping this local
  /// app lock lightweight and dependency-free beyond `crypto`.
  String _hashPin(String pin) {
    List<int> bytes = utf8.encode('hiraukan:app-lock:v1:$pin');
    for (var i = 0; i < 20000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64UrlEncode(bytes);
  }

  bool verifyPin(String pin) {
    final storedHash = StorageService.getString(_pinHashKey);
    if (storedHash == null || storedHash.isEmpty) return false;
    return _hashPin(pin) == storedHash;
  }

  Future<void> setPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < 4 || normalized.length > 8) {
      throw ArgumentError('PIN must contain 4-8 digits.');
    }
    if (!RegExp(r'^\d+$').hasMatch(normalized)) {
      throw ArgumentError('PIN must contain digits only.');
    }

    await StorageService.setString(_pinHashKey, _hashPin(normalized));
    _notifyChanged();
  }

  Future<void> enable({
    required String pin,
    bool biometric = false,
  }) async {
    await setPin(pin);
    await StorageService.setBool(_biometricKey, biometric);
    await StorageService.setBool(_enabledKey, true);
    _backgroundedAt = null;
    _notifyChanged();
  }

  Future<void> disable() async {
    await StorageService.setBool(_enabledKey, false);
    await StorageService.setBool(_biometricKey, false);
    await StorageService.remove(_pinHashKey);
    _backgroundedAt = null;
    _notifyChanged();
  }

  Future<void> setBiometricEnabled(bool value) async {
    await StorageService.setBool(_biometricKey, value);
    _notifyChanged();
  }

  Future<void> setAutoLockTimeout(int minutes) async {
    if (minutes < -1) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    await StorageService.setInt(_autoLockTimeoutKey, minutes);
    _notifyChanged();
  }

  void notifyAppBackgrounded() {
    if (!isEnabled) return;
    _backgroundedAt ??= DateTime.now();
  }

  /// Returns true when the foreground transition should lock the app again.
  bool notifyAppForegrounded() {
    if (!isEnabled) {
      _backgroundedAt = null;
      return false;
    }

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) return false;

    final timeout = autoLockTimeoutMinutes;
    if (timeout < 0) return false;
    if (timeout == 0) return true;

    return DateTime.now().difference(backgroundedAt) >=
        Duration(minutes: timeout);
  }
}
