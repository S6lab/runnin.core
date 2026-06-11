import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/router/app_router.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';

/// Listener app-level que reage ao comando `startRun` vindo do Watch.
///
/// Existe porque [RunBloc] vive dentro do ShellRoute `/prep ↔ /run ↔ /report`
/// (ver [app_router.dart]) — quando o iPhone está em qualquer outra rota
/// (home/profile/training/etc), não há RunBloc inscrito no
/// `watchCommandStream`. O Watch envia `startRun` → iPhone roteia pro Dart
/// via `watch_command` → broadcast pra nenhum listener → silently dropped.
/// Watch fica esperando `status=active` que nunca vem.
///
/// Solução: handler app-level navega o iPhone pra `/run` com
/// `extra={..., autoStart: true}`. ActiveRunPage detecta a flag e dispara
/// StartRun no initState — mesmo efeito de bater INICIAR no prep.
///
/// TF 82 R4: com o iPhone SUSPENSO, nem esse listener roda — o comando era
/// perdido e o Watch caía no "TENTAR NOVAMENTE". Agora o plugin nativo
/// persiste o startRun pendente; consumimos no cold start e em todo resume,
/// então abrir o iPhone inicia a corrida sozinho.
class WatchStartListener with WidgetsBindingObserver {
  StreamSubscription<WatchCommand>? _sub;

  void start() {
    _sub?.cancel();
    _sub = workoutRealtimeService.watchCommandStream.listen(_handle);
    WidgetsBinding.instance.addObserver(this);
    _consumePending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _consumePending();
  }

  Future<void> _consumePending() async {
    final cmd = await workoutRealtimeService.consumePendingWatchStart();
    if (cmd != null) _handle(cmd);
  }

  void _handle(WatchCommand cmd) {
    if (cmd.action != 'startRun') return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    // Se já estamos dentro do shell de corrida, deixa o RunBloc do shell
    // processar (caminho original). Evita duplo dispatch.
    final loc = GoRouter.of(ctx)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    if (loc.startsWith('/prep') ||
        loc.startsWith('/run') ||
        loc.startsWith('/report')) {
      return;
    }
    final p = cmd.payload;
    ctx.go('/run', extra: {
      'type': (p['type'] as String?) ?? 'Free Run',
      'planSessionId': p['planSessionId'] as String?,
      'isPremium': p['isPremium'] == true,
      // ActiveRunPage dispara StartRun no initState quando vê autoStart=true.
      'autoStart': true,
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _sub = null;
  }
}

final watchStartListener = WatchStartListener();
