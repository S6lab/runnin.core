import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:runnin/core/analytics/analytics_service.dart';
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

  /// Bridge pra ActivityKit no iOS 16.2+. Implementado em
  /// `ios/Runner/LiveActivityPlugin.swift`. Em outros platforms o channel
  /// existe mas `isSupported` retorna false e a gente cai pra notif local.
  static const _liveActivityChannel = MethodChannel('runnin/live_activity');

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;
  /// Cache do isSupported da Live Activity — null antes da 1ª checagem.
  /// Setado em [_isLiveActivitySupported] (uma vez por sessão) e usado pra
  /// rotear update/cancel pro caminho certo.
  bool? _liveActivitySupported;
  /// True quando a Live Activity atual foi iniciada com sucesso. Garante
  /// que cancel() chame end() no plugin e que updates subsequentes saibam
  /// que tem activity rodando (não precisam re-pedir start).
  bool _liveActivityStarted = false;
  /// Setado quando o start retornou `activities_disabled` — user desligou
  /// "Atividades Ao Vivo" em Ajustes → Runnin → Notificações. UI consulta
  /// via [isLiveActivityDisabled] pra mostrar banner orientativo. Resetado
  /// quando o user reativa e o start vai bem.
  bool _liveActivityDisabled = false;

  /// True quando a Live Activity está sendo bloqueada por config do user
  /// (vs falha temporária de plataforma). UI (active_run_page) consulta e
  /// renderiza banner discreto com instrução de como reativar.
  bool get isLiveActivityDisabled => _liveActivityDisabled;

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Idempotente: chama plugin nativo no 1º call e cacheia. iOS < 16.2 e
  /// não-iOS sempre retornam false. Falhas (plugin não registrado,
  /// MissingPluginException) também caem em false silenciosamente.
  Future<bool> _isLiveActivitySupported() async {
    final cached = _liveActivitySupported;
    if (cached != null) return cached;
    if (kIsWeb || !Platform.isIOS) {
      _liveActivitySupported = false;
      return false;
    }
    try {
      final res = await _liveActivityChannel.invokeMethod<bool>('isSupported');
      _liveActivitySupported = res ?? false;
    } on PlatformException catch (e, st) {
      Logger.warn('live_activity.is_supported_err', context: {'err': '$e'});
      Logger.error('live_activity.is_supported_err', e, st);
      _liveActivitySupported = false;
    } catch (_) {
      _liveActivitySupported = false;
    }
    return _liveActivitySupported!;
  }

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

  /// Última payload mostrada — usado pra deduplicar updates idênticos a 1Hz
  /// (sem mudar km/pace/tempo, evita re-render desnecessário no iOS).
  String? _lastPayload;

  /// Mostra/atualiza a notificação. Pode ser chamada a 1Hz pelo timer da run
  /// (em background): a notif mostra km · tempo · pace formando um "card
  /// vivo" no lock screen. Antes só era chamada por km cruzado e o card
  /// parecia estático.
  ///
  /// iOS: `interruptionLevel: timeSensitive` + `presentBanner: false` evita
  /// banner toast a cada update (só atualiza silenciosamente). Pra ficar
  /// realmente "ao vivo" estilo Spotify/Strava precisaria de ActivityKit
  /// (Widget Extension target separado) — escopo de follow-up.
  ///
  /// Android: `ongoing: true` + `usesChronometer: true` já dá efeito vivo
  /// (cronômetro tickando) e atualizar o body a 1Hz refresca pace/km.
  Future<void> update({
    required double distanceM,
    required int elapsedS,
    double? paceMinKm,
    String? sessionType,
  }) async {
    if (!_isSupported) return;

    // Caminho preferencial: Live Activity (iOS 16.2+). Renderiza card
    // grande no lock screen + Dynamic Island com pace/km/tempo em mono
    // bold. Quando suportado, NÃO disparamos a notif local (evita
    // duplicação visual). Caller não precisa saber qual caminho rodou.
    if (await _isLiveActivitySupported()) {
      try {
        final method = _liveActivityStarted ? 'update' : 'start';
        // Plugin agora retorna Map {ok, reason?, error?, id?} pra desambiguar
        // os modos de falha (activities_disabled vs request_threw). Versão
        // antiga retornava só bool — defensive parse cobre os 2 formatos.
        final res = await _liveActivityChannel.invokeMethod<Object>(method, {
          'distanceM': distanceM,
          'elapsedS': elapsedS,
          'paceMinKm': ?paceMinKm,
          'sessionType': ?sessionType,
        });
        final ok = res is Map ? res['ok'] == true : res == true;
        if (ok) {
          if (!_liveActivityStarted) {
            Logger.info('live_activity.start.success');
            _liveActivityDisabled = false;
          }
          _liveActivityStarted = true;
          return;
        }
        // Falhou — distinguir motivo pra UI poder mostrar banner orientativo.
        final reason = res is Map ? (res['reason'] as String? ?? 'unknown') : 'unknown';
        Logger.warn('live_activity.$method.failed reason=$reason');
        if (reason == 'activities_disabled' && !_liveActivityDisabled) {
          _liveActivityDisabled = true;
          analytics.logEvent('live_activity.disabled_by_user', params: const {});
        }
      } on PlatformException catch (e, st) {
        Logger.error('live_activity.invoke_failed', e, st);
        // fall through pro fallback
      }
    }

    if (!_initialized) await init();
    if (!_permissionGranted) {
      // Tenta pedir silenciosamente; iOS só mostra popup se ainda não viu.
      await requestPermissions();
      if (!_permissionGranted) return;
    }
    final km = (distanceM / 1000).toStringAsFixed(2);
    final timeLabel = _fmtTime(elapsedS);
    final paceLabel = _fmtPace(paceMinKm);
    final body = paceLabel != null
        ? '$km km · $timeLabel · $paceLabel/km'
        : '$km km · $timeLabel';
    if (body == _lastPayload) return; // dedup pra ticks com mesmo segundo
    _lastPayload = body;
    try {
      await _plugin.show(
        _notifId,
        'Corrida em andamento',
        body,
        NotificationDetails(
          iOS: const DarwinNotificationDetails(
            // presentBanner=false: updates a 1Hz não devem mostrar banner.
            // O card no lock screen continua visível, mas sem toast por
            // segundo. interruptionLevel mantém visibilidade no Foco.
            presentAlert: false,
            presentBanner: false,
            presentSound: false,
            interruptionLevel: InterruptionLevel.timeSensitive,
            threadIdentifier: 'runnin.run.active',
          ),
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            // importance low: ficar silencioso ao atualizar a cada 1s.
            // O canal manter HIGH no init garante visibilidade no lock screen.
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: true,
            usesChronometer: true,
            onlyAlertOnce: true,
            category: AndroidNotificationCategory.workout,
          ),
        ),
      );
    } catch (e, st) {
      Logger.error('run_bg_notif.update_failed', e, st);
    }
  }

  /// Alias antigo — mantém API anterior pra callers que só queriam mostrar
  /// uma vez (ex: ao entrar em bg). Internamente delega pra update().
  Future<void> show({required double distanceM, required int elapsedS}) {
    return update(distanceM: distanceM, elapsedS: elapsedS);
  }

  Future<void> cancel() async {
    if (!_isSupported) return;
    _lastPayload = null;
    // Encerra a Live Activity primeiro (se rolou). dismissalPolicy
    // .immediate no plugin nativo tira do lock screen na hora.
    if (_liveActivityStarted) {
      try {
        await _liveActivityChannel.invokeMethod('end');
      } catch (e, st) {
        Logger.error('live_activity.end_failed', e, st);
      }
      _liveActivityStarted = false;
    }
    try {
      await _plugin.cancel(_notifId);
    } catch (e, st) {
      Logger.error('run_bg_notif.cancel_failed', e, st);
    }
  }

  /// Pace em min/km → "mm:ss". null/0 → null (omitimos do body).
  static String? _fmtPace(double? p) {
    if (p == null || !p.isFinite || p <= 0) return null;
    final min = p.floor();
    final sec = ((p - min) * 60).round();
    if (sec == 60) return '${min + 1}:00';
    return '$min:${sec.toString().padLeft(2, '0')}';
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
