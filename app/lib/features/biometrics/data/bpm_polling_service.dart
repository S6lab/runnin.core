import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';

/// Polling do BPM mais recente do plugin `health` (Apple Health / Health
/// Connect) pra alimentar cards da home/perfil que NÃO precisam de stream
/// nativo (HKAnchored é exclusivo da Run ativa via WorkoutRealtimeService).
///
/// Singleton top-level alinhado com `healthSyncService` e
/// `workoutRealtimeService` — convenção do app pra evitar pulverizar DI.
///
/// Estratégia:
///   - `Timer.periodic(2min)` chama `healthSyncService.latestBpm(withinSeconds: 21600)`
///     (6h window pra pegar leitura recente do Apple Watch).
///   - `WidgetsBindingObserver`: pausa quando app vai pra background
///     (poupa bateria); resume quando volta.
///   - Refcount: `latestBpmStream` é broadcast com replay-on-listen do
///     último valor cacheado. Primeiro listener inicia o timer; quando 0
///     listeners, timer é cancelado.
class BpmPollingService with WidgetsBindingObserver {
  BpmPollingService._();

  static final instance = BpmPollingService._();

  static const _pollInterval = Duration(minutes: 2);
  static const _withinSeconds = 21600; // 6h

  final _controller = StreamController<int?>.broadcast();
  Timer? _timer;
  int? _latest;
  int _listenerCount = 0;
  bool _observerRegistered = false;
  bool _appPaused = false;

  /// Último BPM emitido (snapshot sync, replay-on-listen).
  int? get latestBpm => _latest;

  /// Broadcast stream. Cada novo listener recebe o último valor cacheado
  /// imediatamente; o timer só roda enquanto houver pelo menos 1 listener.
  Stream<int?> get latestBpmStream async* {
    _attach();
    if (_latest != null) yield _latest;
    yield* _controller.stream;
  }

  void _attach() {
    _listenerCount += 1;
    if (_listenerCount == 1) {
      if (!_observerRegistered) {
        WidgetsBinding.instance.addObserver(this);
        _observerRegistered = true;
      }
      _startTimer();
      // Fetch inicial imediato pra não esperar 2min na primeira leitura.
      unawaited(_poll());
    }
  }

  void _detach() {
    if (_listenerCount > 0) _listenerCount -= 1;
    if (_listenerCount == 0) _stopTimer();
  }

  void _startTimer() {
    if (_appPaused) return;
    _timer ??= Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    try {
      final bpm = await healthSyncService.latestBpm(withinSeconds: _withinSeconds);
      _latest = bpm;
      if (!_controller.isClosed) _controller.add(bpm);
    } catch (e, st) {
      Logger.warn('bpm_polling.fetch_failed', context: {'err': '$e'});
      Logger.error('bpm_polling.fetch_failed', e, st);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final goingBg = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (goingBg && !_appPaused) {
      _appPaused = true;
      _stopTimer();
    } else if (state == AppLifecycleState.resumed && _appPaused) {
      _appPaused = false;
      if (_listenerCount > 0) {
        _startTimer();
        unawaited(_poll());
      }
    }
  }
}

/// Singleton top-level (alinhado com `healthSyncService`).
final bpmPollingService = BpmPollingService.instance;

/// Hook auxiliar pra widgets fora do StreamBuilder. Decremento manual quando
/// o StreamBuilder unsubscribe — handler interno do StreamController não
/// expõe onCancel pra a callbacks externas direto.
extension BpmPollingServiceListen on BpmPollingService {
  /// Stream que decrementa o refcount quando o listener cancela. Use em vez
  /// de `latestBpmStream` direto se você precisa de cancel determinístico.
  Stream<int?> get latestBpmStreamWithRefcount {
    late StreamController<int?> proxy;
    StreamSubscription<int?>? sub;
    proxy = StreamController<int?>(
      onListen: () {
        sub = latestBpmStream.listen(proxy.add, onError: proxy.addError);
      },
      onCancel: () async {
        await sub?.cancel();
        _detach();
      },
    );
    return proxy.stream;
  }
}
