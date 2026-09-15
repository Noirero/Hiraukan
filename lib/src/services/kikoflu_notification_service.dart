import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'kikoflu_feature_settings.dart';
import 'log_service.dart';

final _log = LogService.instance;

/// Android notification bridge derived from KikoFlu.
///
/// Local task/progress notifications work without Firebase. FCM remains
/// strictly opt-in and only becomes enabled when this Hiraukan build contains
/// its own valid Firebase configuration. KikoFlu Firebase credentials are never
/// reused.
class KikoFluNotificationService {
  KikoFluNotificationService._();
  static final instance = KikoFluNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _localReady = false;
  bool _firebaseReady = false;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  bool get firebaseReady => _firebaseReady;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    if (!_localReady) {
      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      try {
        await _local.initialize(
          const InitializationSettings(android: android),
        );
        _localReady = true;
      } catch (error) {
        _log.warning('Local notification init skipped: $error', tag: 'Notify');
      }
    }

    if (KikoFluFeatureSettings.instance.fcmEnabled) {
      final ready = await initializeFirebaseIfConfigured();
      if (!ready) {
        await KikoFluFeatureSettings.instance.setFcmEnabled(false);
      }
    }
  }

  Future<bool> requestLocalPermission() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    if (!_localReady) return false;
    try {
      return await _local
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    } catch (error) {
      _log.warning('Notification permission request failed: $error', tag: 'Notify');
      return false;
    }
  }

  Future<bool> initializeFirebaseIfConfigured() async {
    if (!Platform.isAndroid) return false;
    if (_firebaseReady && _foregroundSubscription != null) return true;

    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _firebaseReady = false;
        return false;
      }

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

  /// Returns the effective enabled state after applying the request.
  Future<bool> setFcmEnabled(bool enabled) async {
    if (!enabled) {
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

    final ready = await initializeFirebaseIfConfigured();
    if (!ready) {
      await _foregroundSubscription?.cancel();
      _foregroundSubscription = null;
      _firebaseReady = false;
    }
    return ready;
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
    if (!Platform.isAndroid ||
        !KikoFluFeatureSettings.instance.notificationsEnabled) {
      return;
    }
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
    if (!Platform.isAndroid ||
        !KikoFluFeatureSettings.instance.notificationsEnabled) {
      return;
    }
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
