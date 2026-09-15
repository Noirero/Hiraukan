import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'kikoflu_feature_settings.dart';
import 'log_service.dart';

final _log = LogService.instance;

/// Notification bridge derived from KikoFlu.
/// Local progress notifications work independently. FCM is opt-in and only
/// initializes when a valid Firebase configuration is present in Hiraukan.
class KikoFluNotificationService {
  KikoFluNotificationService._();
  static final instance = KikoFluNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  bool _firebaseReady = false;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  Future<void> initialize() async {
    if (!_localReady) {
      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwin = DarwinInitializationSettings();
      try {
        await _local.initialize(
          const InitializationSettings(
            android: android,
            iOS: darwin,
            macOS: darwin,
          ),
        );
        _localReady = true;
      } catch (error) {
        _log.warning('Local notification init skipped: $error', tag: 'Notify');
      }
    }

    if (KikoFluFeatureSettings.instance.fcmEnabled) {
      await initializeFirebaseIfConfigured();
    }
  }

  Future<bool> initializeFirebaseIfConfigured() async {
    if (_firebaseReady && _foregroundSubscription != null) return true;
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _firebaseReady = true;
      _foregroundSubscription ??=
          FirebaseMessaging.onMessage.listen((message) async {
        if (!KikoFluFeatureSettings.instance.fcmEnabled) return;
        final notification = message.notification;
        if (notification == null) return;
        await showMessage(
          id: message.messageId?.hashCode ?? notification.hashCode,
          title: notification.title ?? 'Hiraukan',
          body: notification.body ?? '',
        );
      });
      return true;
    } catch (error) {
      _log.warning(
        'Firebase configuration unavailable; FCM remains disabled: $error',
        tag: 'Notify',
      );
      _firebaseReady = false;
      return false;
    }
  }

  /// Applies the FCM toggle immediately. Turning it off removes the foreground
  /// listener and best-effort deletes the token, so disabling the feature does
  /// not keep delivering KikoFlu-derived push behavior in the current session.
  Future<bool> setFcmEnabled(bool enabled) async {
    if (enabled) return initializeFirebaseIfConfigured();

    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _firebaseReady = false;
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (error) {
      _log.warning('FCM token cleanup skipped: $error', tag: 'Notify');
    }
    return false;
  }

  Future<String?> getFcmToken() async {
    if (!KikoFluFeatureSettings.instance.fcmEnabled) return null;
    if (!await initializeFirebaseIfConfigured()) return null;
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!KikoFluFeatureSettings.instance.notificationsEnabled) return;
    await initialize();
    if (!_localReady) return;
    await _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hiraukan_tasks',
          'Hiraukan Tasks',
          channelDescription: 'Download, conversion and transcription progress',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    if (!KikoFluFeatureSettings.instance.notificationsEnabled) return;
    await initialize();
    if (!_localReady) return;
    final safeMax = maxProgress <= 0 ? 100 : maxProgress;
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hiraukan_tasks',
          'Hiraukan Tasks',
          channelDescription: 'Download, conversion and transcription progress',
          onlyAlertOnce: true,
          showProgress: true,
          progress: progress.clamp(0, safeMax),
          maxProgress: safeMax,
        ),
      ),
    );
  }

  Future<void> cancel(int id) => _local.cancel(id);
}
