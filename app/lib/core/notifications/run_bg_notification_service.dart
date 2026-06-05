import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:runnin/core/logger/logger.dart';

/// Notificação persistente que aparece na bandeja/lock screen enquanto a
/// corrida está em background. Confirma visualmente pro user que a corrida
/// continua trackeada mesmo com a app fechada — padrão de UX de apps de
/// fitness (Strava, Nike Run).
///
/// iOS: notificação local com `interruptionLevel: timeSensitive` aparece
/// na lock screen + notification center. Não é "always visible" estilo
/// Live Activity (isso exigiria ActivityKit + extension target), mas é
/// suficiente pro user enxergar que a app está rodando.
///
/// Android: notification do canal `runnin_run_active` (importance HIGH)
/// + `ongoing=true` torna a notification não-dismissable, equivalente
/// a um foreground service notification (mais controle de copy/icon
/// que o foregroundNotificationConfig do geolocator).
///
/// Lifecycle (chamado pelo [RunBloc]):
///   - run start: [requestPermissions()] uma vez
///   - app → background com run ativa: [show()]
///   - app → foreground OU run para: [cancel()]
class RunBgNotificationService {
  RunBgNotificationService._();
  static final RunBgNotificationService instance = RunBgNotificationService._();

  static const _notifId = 8181;
  static const _channelId = 'runnin_run_active';
  static const _channelName = 'Corrida em andamento';
  static const _channelDescription =
      'Notificação persistente exibida enquanto a corrida está rodando em background.';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<void> init() async {
    if (_initialized || !_isSupported) return;
    try {
      const init = InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(init);

      if (Platform.isAndroid) {
        // Cria canal explicitamente — sem isso, no Android 8+ a notif não
        // aparece se o canal nunca foi registrado.
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        );
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
      _initialized = true;
      Logger.info('run_bg_notif.init_ok');
    } catch (e, st) {
      Logger.error('run_bg_notif.init_failed', e, st);
    }
  }

  /// Pede permissão de notificação. iOS abre o popup; Android 13+ idem.
  /// Idempotente — não pede de novo se já concedido.
  Future<bool> requestPermissions() async {
    if (!_isSupported) return false;
    await init();
    try {
      if (Platform.isIOS) {
        final granted = await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: false, sound: false) ??
            false;
        _permissionGranted = granted;
        Logger.info('run_bg_notif.permission_ios',
            context: {'granted': granted});
        return granted;
      }
      if (Platform.isAndroid) {
        final granted = await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
        _permissionGranted = granted;
        Logger.info('run_bg_notif.permission_android',
            context: {'granted': granted});
        return granted;
      }
      return false;
    } catch (e, st) {
      Logger.error('run_bg_notif.permission_failed', e, st);
      return false;
    }
  }

  /// Mostra/atualiza a notificação. Caller passa [distanceM] e [elapsedS]
  /// pra refletir o estado atual; chamar a cada km fechado mantém o card
  /// atualizado.
  Future<void> show({required double distanceM, required int elapsedS}) async {
    if (!_isSupported) return;
    if (!_initialized) await init();
    if (!_permissionGranted) {
      // Tenta pedir silenciosamente; iOS só mostra popup se ainda não viu.
      await requestPermissions();
      if (!_permissionGranted) return;
    }
    final km = (distanceM / 1000).toStringAsFixed(2);
    final timeLabel = _fmtTime(elapsedS);
    try {
      await _plugin.show(
        _notifId,
        'Corrida em andamento',
        '${km}km · $timeLabel',
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: false,
            interruptionLevel: InterruptionLevel.timeSensitive,
            threadIdentifier: 'runnin.run.active',
          ),
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            usesChronometer: true,
            category: AndroidNotificationCategory.workout,
          ),
        ),
      );
    } catch (e, st) {
      Logger.error('run_bg_notif.show_failed', e, st);
    }
  }

  Future<void> cancel() async {
    if (!_isSupported) return;
    try {
      await _plugin.cancel(_notifId);
    } catch (e, st) {
      Logger.error('run_bg_notif.cancel_failed', e, st);
    }
  }

  static String _fmtTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Singleton top-level alinhado com o padrão do app (healthSyncService etc).
final runBgNotificationService = RunBgNotificationService.instance;
