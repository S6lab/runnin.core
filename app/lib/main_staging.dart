import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

import 'package:runnin/core/notifications/run_bg_notification_service.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/run/watch_start_listener.dart';
import 'package:runnin/features/run/watch_today_session_pusher.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: StagingFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  await themeController.load();

  // Limpa qualquer sessão anônima leftover (do tempo em que a app fazia
  // signInAnonymously no boot). Sem isso, o user reabre o app já "logado"
  // como anônimo, pula a tela /login e cai direto em onboarding.
  if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
    await FirebaseAuth.instance.signOut();
  }

  if (FirebaseAuth.instance.currentUser != null) {
    try {
      await UserRemoteDatasource().provisionMe();
    } catch (_) {
      // O app continua mesmo se a sincronização inicial falhar.
    }
    // Live Activities: prompt nativo do iOS aparece via Activity.request().
    // No primeiro boot, dispara o prompt 1x — depois disso iOS lembra a
    // escolha. Sem isso, user só vê o prompt na primeira corrida em bg.
    Future.microtask(() => runBgNotificationService.primeLiveActivityPermission());
    // Empurra a sessão planejada de HOJE pro Watch logo no boot + retries
    // em 3s e 8s. iOS sim tem race onde o primeiro push perde se Watch
    // ainda está ativando WCSession; retries cobrem essa janela.
    Future.microtask(() => watchTodaySessionPusher.pushTodayWithRetries());
  }

  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  // Listener app-level pro comando startRun do Watch quando o iPhone está
  // fora do shell de corrida (RunBloc só existe lá). Navega pra /run com
  // autoStart=true.
  watchStartListener.start();

  // Skin sync: quando user troca a skin no iPhone, empurra um
  // applicationContext mínimo pra Watch refletir a nova cor de acento.
  // pushRunState auto-injeta `accentColor` da skin atual.
  themeController.addListener(() {
    unawaited(workoutRealtimeService.pushRunState({'type': 'run_state'}));
  });

  // Watch app reinstalado: re-empurra today_session (cache zerado).
  workoutRealtimeService.watchAppInstalledStream.listen((_) {
    unawaited(watchTodaySessionPusher.pushToday());
  });

  // Watch ficou reachable agora (estava offline antes): garante que ele
  // recebe today_session mesmo que o push anterior tenha sido descartado por
  // race de timing (iPhone empurra antes do Watch ativar a session). Sem
  // isso o Watch fica com TypeSelectorScreen "vazia" até o user fazer
  // alguma ação no iPhone.
  workoutRealtimeService.watchReconnectedStream.listen((_) {
    unawaited(watchTodaySessionPusher.pushToday());
  });

  runApp(const ProviderScope(child: RunrunApp()));
}

class RunrunApp extends StatelessWidget {
  const RunrunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp.router(
        title: 'runnin.ai (Staging)',
        theme: AppTheme.build(themeController.palette),
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(themeController.textScaleFactor),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
