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
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await themeController.load();

  final isAdminEntry =
      Uri.base.path == '/admin' || Uri.base.path.startsWith('/admin/');

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
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
