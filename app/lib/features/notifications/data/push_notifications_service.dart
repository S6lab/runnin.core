import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:runnin/core/network/api_client.dart';

/// Init FCM + registra token no backend.
///
/// - Web: usa VAPID key opcional via --dart-define=FIREBASE_VAPID_KEY.
/// - iOS/Android: solicita permissão de notificação.
/// - Backend recebe POST /notifications/devices { token, platform }.
class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  static const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  Future<void> initAndRegister() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await messaging.getToken(
        vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null,
      );
      if (token == null || token.isEmpty) return;
      await _sendTokenToServer(token);

      messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToServer(newToken).catchError((_) {});
      });
    } catch (e) {
      if (kDebugMode) debugPrint('push.init_failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    if (FirebaseAuth.instance.currentUser == null) return;
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'unknown';
    await apiClient.post<void>('/notifications/devices', data: {
      'token': token,
      'platform': platform,
    });
  }
}
