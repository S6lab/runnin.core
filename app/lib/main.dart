import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/notifications/run_bg_notification_service.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/notifications/data/push_notifications_service.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/run/watch_start_listener.dart';
import 'package:runnin/features/run/watch_today_session_pusher.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/core/remote_config/force_update_controller.dart';
import 'package:runnin/features/force_update/presentation/pages/force_update_page.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'firebase_options.dart';

void main() async {
  // Captura QUALQUER erro não tratado (Futures sem catch, microtasks órfãs).
  // Sem isso, em release web o erro vira "Uncaught Error" sem mensagem.
  runZonedGuarded(_runApp, (error, stack) {
    // ignore: avoid_print
    print('[ZONE_ERROR] $error\n$stack');
    if (!kIsWeb) {
      // Reporta erro fatal capturado pela zone (escapou de FlutterError.onError
      // e PlatformDispatcher.onError — ex.: throws síncronos pré-binding).
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await themeController.load();

  // Inicializa canal/permissão da notificação persistente da run (bandeja /
  // lock screen quando app vai pra background mid-corrida). iOS pede
  // permissão real só quando a notif é solicitada pela primeira vez no
  // RunBloc — aqui é só init de canal/handler.
  unawaited(runBgNotificationService.init());

  final isAdminEntry =
      Uri.base.path == '/admin' || Uri.base.path.startsWith('/admin/');

  // Gate de manutenção / atualização obrigatória (Remote Config). Roda em
  // background — não bloqueia o boot; quando resolve, o builder do app exibe
  // a tela de bloqueio se necessário. Fail-open em caso de erro.
  if (!isAdminEntry) {
    forceUpdateController.check();
  }

  // Limpa qualquer sessão anônima leftover (do tempo em que a app fazia
  // signInAnonymously no boot). Sem isso, o user reabre o app já "logado"
  // como anônimo, pula a tela /login e cai direto em onboarding.
  if (!isAdminEntry &&
      FirebaseAuth.instance.currentUser?.isAnonymous == true) {
    await FirebaseAuth.instance.signOut();
  }

  if (!isAdminEntry && FirebaseAuth.instance.currentUser != null) {
    try {
      await UserRemoteDatasource().provisionMe();
    } catch (_) {
      // O app continua mesmo se a sincronização inicial falhar.
    }
    // Carrega plano + features em background — não bloqueia o boot.
    subscriptionController.refresh();

    // Auto-sync de biométricos (Apple Health / Health Connect). Se user já
    // concedeu permissão antes, puxa samples desde último sync. Não bloqueia
    // o boot — roda em background. Sem permissão / web: no-op silencioso.
    if (healthSyncService.isSupported) {
      Future.microtask(() async {
        try {
          if (await healthSyncService.hasPermissions()) {
            await healthSyncService.syncSince();
          }
        } catch (e, st) {
          // Falha de sync nunca quebra o app, mas precisamos saber que aconteceu.
          if (!kIsWeb) {
            FirebaseCrashlytics.instance
                .recordError(e, st, reason: 'wearable_boot_autosync_failed');
          }
        }
      });
    }

    // FCM push: pede permissão + registra token no backend.
    Future.microtask(() => PushNotificationsService.instance.initAndRegister());

    // Live Activities: dispara prompt nativo do iOS no 1º boot (1x por
    // instalação). Sem isso, user só vê o prompt na primeira corrida em bg
    // — e se a corrida durar pouco, o prompt pode passar despercebido.
    Future.microtask(() => runBgNotificationService.primeLiveActivityPermission());

    // Empurra a sessão planejada de HOJE pro Watch logo no boot + retries
    // em 3s e 8s. Sem isso, race do iOS sim faz o primeiro push perder se
    // Watch ainda está ativando WCSession; retries cobrem essa janela.
    Future.microtask(() => watchTodaySessionPusher.pushTodayWithRetries());
  }

  // Listener app-level pro comando startRun do Watch quando o iPhone está
  // fora do shell de corrida (RunBloc só existe lá). Navega pra /run com
  // autoStart=true e ActiveRunPage dispara StartRun no initState.
  watchStartListener.start();

  // Skin sync: quando user troca a skin no iPhone, empurra um
  // applicationContext mínimo pra Watch refletir a nova cor de acento.
  // pushRunState auto-injeta `accentColor` da skin atual.
  themeController.addListener(() {
    unawaited(workoutRealtimeService.pushRunState({'type': 'run_state'}));
  });

  // Watch app reinstalado (user removeu e voltou OU dev reinstalou em build):
  // o cache de applicationContext do Watch é zerado. Re-empurra today_session
  // pra ele recuperar SESSÃO DO DIA + skin + textScale sem precisar abrir
  // /prep no iPhone manualmente.
  workoutRealtimeService.watchAppInstalledStream.listen((_) {
    unawaited(watchTodaySessionPusher.pushToday());
  });

  // Watch reconectou (reachable false→true): empurra today_session de novo
  // pra cobrir race onde Watch ativou DEPOIS do iPhone empurrar.
  workoutRealtimeService.watchReconnectedStream.listen((_) {
    unawaited(watchTodaySessionPusher.pushToday());
  });

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Async errors fora do framework (PlatformChannels, plugins nativos como
    // google_sign_in / firebase_auth) caem aqui — sem isso o Crashlytics nunca
    // vê esses crashes.
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } else {
    // Em release web, Dart strippa as mensagens de erro do bundle ("Uncaught
    // Error" sem detalhes). Esses handlers convertem o erro pra string ANTES
    // do strip, surfaçando msg + stacktrace no console pra diagnóstico.
    FlutterError.onError = (FlutterErrorDetails details) {
      // ignore: avoid_print
      print('[FLUTTER_ERROR] ${details.exceptionAsString()}\n${details.stack}');
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      // ignore: avoid_print
      print('[PLATFORM_ERROR] $error\n$stack');
      return true;
    };
  }

  runApp(const ProviderScope(child: RunrunApp()));
}

class RunrunApp extends StatelessWidget {
  const RunrunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp.router(
        title: 'runnin.ai',
        theme: AppTheme.build(themeController.palette),
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        builder: (context, child) {
          // Aplica o textScale global (3 níveis: A−/A/A+) escolhido no perfil.
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(themeController.textScaleFactor),
            ),
            // Overlay de bloqueio (manutenção / update obrigatório) sobre
            // qualquer rota quando o Remote Config indicar.
            child: AnimatedBuilder(
              animation: forceUpdateController,
              builder: (context, _) => forceUpdateController.blocked
                  ? const ForceUpdatePage()
                  : (child ?? const SizedBox.shrink()),
            ),
          );
        },
      ),
    );
  }
}
