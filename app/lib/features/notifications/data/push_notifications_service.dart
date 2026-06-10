import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/features/badges/presentation/badge_controller.dart';
import 'package:runnin/features/badges/presentation/pages/badge_popup_modal.dart';

/// Init FCM + registra token no backend + roteia taps de push pra rota
/// correta no app.
///
/// - Web: usa VAPID key opcional via --dart-define=FIREBASE_VAPID_KEY.
/// - iOS/Android: solicita permissão de notificação.
/// - Backend recebe POST /notifications/devices { token, platform }.
/// - Pushes do server vêm com `data.route` — esse handler navega via
///   rootNavigator quando o usuário tappa em background ou cold start.
class PushNotificationsService {
  PushNotificationsService._();
  static final PushNotificationsService instance = PushNotificationsService._();

  static const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  bool _handlersAttached = false;

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

      _attachHandlers(messaging);
    } catch (e) {
      if (kDebugMode) debugPrint('push.init_failed: $e');
    }
  }

  void _attachHandlers(FirebaseMessaging messaging) {
    if (_handlersAttached) return;
    _handlersAttached = true;

    // Cold start: app aberto pelo tap numa push enquanto estava killed.
    // getInitialMessage() retorna a mensagem que abriu o app (ou null).
    // Atraso pra rodar depois do router estar montado.
    messaging.getInitialMessage().then((msg) {
      if (msg != null) _handleTap(msg);
    });

    // Background tap: app estava em background/lock screen e user tappou.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Foreground: notif chegou com app aberto. Não navega (seria intrusivo);
    // só registra pro caller eventualmente refrescar a lista.
    // Plataforma decide se mostra UI nativa (iOS suprime por default sem
    // setForegroundNotificationPresentationOptions).
    FirebaseMessaging.onMessage.listen((msg) {
      if (kDebugMode) {
        debugPrint('push.foreground: ${msg.data}');
      }
      // Hook futuro: chamar notificationsCubit.load() se houver listener
      // global; por enquanto a tela /notifications faz silent refresh no
      // initState e o badge da home recarrega ao reabrir.
    });
  }

  /// Lê `data.route` do payload e navega via rootNavigator. Fallback
  /// pra `/notifications` se a rota não vier no payload.
  ///
  /// TF 79: quando `data.kind == 'badge_unlocked'`, primeiro navega pra
  /// `/profile/badges`, depois abre o `BadgePopupModal` do badge específico
  /// via lookup no `BadgeController`. Sem o popup, o user ia precisar
  /// procurar o badge novo na galeria — UX ruim.
  void _handleTap(RemoteMessage msg) {
    final route = msg.data['route'];
    final target = (route is String && route.isNotEmpty)
        ? route
        : '/notifications';
    final kind = msg.data['kind'];
    final badgeId = msg.data['badgeId'];
    // navigatorKey.currentContext só fica disponível depois do build do
    // MaterialApp.router. Em cold start chegamos aqui antes — então
    // agendamos pra próximo frame.
    Future<void>.delayed(const Duration(milliseconds: 50), () async {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      try {
        ctx.push(target);
      } catch (e) {
        if (kDebugMode) debugPrint('push.nav_failed: $e route=$target');
        return;
      }
      if (kind == 'badge_unlocked' && badgeId is String && badgeId.isNotEmpty) {
        // Aguarda a galeria carregar (controller já cacheia all=List<Badge>)
        // e abre o popup do badge alvo. Se o user fechou push depois de
        // markSeen, BadgeController.all ainda devolve o badge — popup
        // mostra como "já visto" sem disparar mark-seen.
        await BadgeController.instance.refresh();
        final target = BadgeController.instance.all
            .where((b) => b.badgeId == badgeId)
            .firstOrNull;
        if (target == null) return;
        final ctx2 = rootNavigatorKey.currentContext;
        if (ctx2 == null || !ctx2.mounted) return;
        await BadgePopupModal.show(ctx2, target);
      }
    });
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
