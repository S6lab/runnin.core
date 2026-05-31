import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/notifications/data/push_notifications_service.dart';
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
        } catch (_) {
          // Falha de sync nunca quebra o app.
        }
      });
    }

    // FCM push: pede permissão + registra token no backend.
    Future.microtask(() => PushNotificationsService.instance.initAndRegister());
  }

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
