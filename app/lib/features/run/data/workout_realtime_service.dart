import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';

import 'package:runnin/core/logger/logger.dart';

/// Estado da sessão de workout. O serviço mantém uma máquina de estados
/// idempotente — start/pause/resume/stop não fazem nada se já estiverem
/// no estado correspondente.
enum WorkoutSessionState { idle, starting, active, paused, stopping }

/// Resultado de `checkAvailability`. `available=false` quando: plataforma
/// não suporta (web), versão do OS abaixo do mínimo, HealthKit/Health
/// Services indisponível, ou device sem capability de heart rate.
class WorkoutAvailability {
  final bool available;
  final String? reason; // 'unsupported_platform' | 'unsupported_os' | 'no_capability' | 'permission_required' | etc

  const WorkoutAvailability({required this.available, this.reason});

  factory WorkoutAvailability.fromMap(Map<dynamic, dynamic> map) =>
      WorkoutAvailability(
        available: map['available'] == true,
        reason: map['reason'] as String?,
      );
}

/// Bridge Dart pra plugins nativos de BPM realtime durante a Run ativa.
///
/// - iOS: `HKWorkoutSession` + `HKLiveWorkoutBuilder` (1Hz heart rate via
///   Apple Watch pareado; integra Activity Ring).
/// - Android: `androidx.health.services.client.HealthServicesClient.getMeasureClient()`
///   com `MeasureCallback` (1Hz via Wear OS pareado).
///
/// O serviço NÃO é responsável pelo histórico de samples (continua via
/// plugin `health` / [HealthSyncService]). Aqui o foco é stream live durante
/// a corrida ativa. Quem chama: [RunBloc] na transição start/pause/resume/
/// stop. UI consome `state.currentBpm` (não esse serviço diretamente).
///
/// Padrão de singleton top-level alinhado com `healthSyncService` — sem
/// riverpod/GetIt no app.
class WorkoutRealtimeService {
  static const _methodChannel = MethodChannel('runnin/workout_realtime');
  static const _eventChannel = EventChannel('runnin/workout_realtime/events');

  WorkoutSessionState _state = WorkoutSessionState.idle;
  int? _latestBpm;
  StreamSubscription<dynamic>? _eventSub;

  final _bpmController = StreamController<int?>.broadcast();
  final _sessionStateController = StreamController<WorkoutSessionState>.broadcast();

  /// Stream de BPMs do wearable. Emite `null` quando a fonte fica indisponível
  /// (Watch desligado, permission revogada). UI fica em '—' silenciosamente.
  ///
  /// Replay-on-listen: cada novo listener recebe imediatamente o `_latestBpm`
  /// cacheado (se houver), pra não perder o último sample emitido antes do
  /// subscribe. Crítico pra evitar race entre `start()` e o listener inicial.
  Stream<int?> get bpmStream async* {
    if (_latestBpm != null) yield _latestBpm;
    yield* _bpmController.stream;
  }

  /// Estados da sessão: idle → starting → active ↔ paused → stopping → idle.
  Stream<WorkoutSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  int? get latestBpm => _latestBpm;
  WorkoutSessionState get state => _state;

  bool get _isSupported => !kIsWeb;

  Future<WorkoutAvailability> checkAvailability() async {
    if (!_isSupported) {
      return const WorkoutAvailability(
        available: false,
        reason: 'unsupported_platform',
      );
    }
    try {
      final result = await _methodChannel.invokeMapMethod<String, Object?>(
        'checkAvailability',
      );
      if (result == null) {
        return const WorkoutAvailability(available: false, reason: 'no_response');
      }
      return WorkoutAvailability.fromMap(result);
    } on PlatformException catch (e) {
      debugPrint('workout_realtime.checkAvailability failed: ${e.message}');
      return WorkoutAvailability(available: false, reason: e.code);
    }
  }

  /// Inicia a sessão de workout nativa. Idempotente — chamadas em
  /// `active/paused/starting` viram no-op. Falha (sem watch, permission
  /// negada) NÃO lança — o stream `bpmStream` permanece em null e
  /// `sessionStateStream` emite eventos de erro pra telemetria.
  Future<void> start() async {
    if (!_isSupported) return;
    if (_state == WorkoutSessionState.starting ||
        _state == WorkoutSessionState.active ||
        _state == WorkoutSessionState.paused) {
      return;
    }
    _setState(WorkoutSessionState.starting);
    _attachEventStream();
    try {
      await _methodChannel.invokeMethod('start');
      // Estado real (active vs error) virá via eventStream do nativo.
    } on PlatformException catch (e, st) {
      Logger.error('workout_realtime.start_failed', e, st, {'code': e.code, 'message': e.message ?? ''});
      _setState(WorkoutSessionState.idle);
    }
  }

  /// Pausa a sessão nativa mantendo o workout como um único evento merged
  /// no HK / Health Connect (iOS chama `HKWorkoutSession.pause()`; Android
  /// faz `unregisterMeasureCallbackAsync` sem encerrar a noção de workout
  /// do user). Idempotente.
  Future<void> pause() async {
    if (!_isSupported) return;
    if (_state != WorkoutSessionState.active) return;
    try {
      await _methodChannel.invokeMethod('pause');
      _setState(WorkoutSessionState.paused);
    } on PlatformException catch (e, st) {
      Logger.error('workout_realtime.pause_failed', e, st, {'code': e.code});
    }
  }

  Future<void> resume() async {
    if (!_isSupported) return;
    if (_state != WorkoutSessionState.paused) return;
    try {
      await _methodChannel.invokeMethod('resume');
      _setState(WorkoutSessionState.active);
    } on PlatformException catch (e, st) {
      Logger.error('workout_realtime.resume_failed', e, st, {'code': e.code});
    }
  }

  /// Encerra a sessão. Crítico: garante que o workout vai pro Activity Ring
  /// (iOS) sem ficar "aberto". Idempotente — chamada em `idle/stopping` é
  /// no-op.
  Future<void> stop() async {
    if (!_isSupported) return;
    if (_state == WorkoutSessionState.idle ||
        _state == WorkoutSessionState.stopping) {
      return;
    }
    _setState(WorkoutSessionState.stopping);
    try {
      await _methodChannel.invokeMethod('stop');
    } on PlatformException catch (e, st) {
      Logger.error('workout_realtime.stop_failed', e, st, {'code': e.code});
    }
    _setState(WorkoutSessionState.idle);
    _detachEventStream();
    _emitBpm(null);
  }

  void _attachEventStream() {
    _eventSub ??= _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e) {
        debugPrint('workout_realtime.event error: $e');
      },
    );
  }

  void _detachEventStream() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  void _onEvent(dynamic raw) {
    // Defensive parse: o EventChannel pode entregar Map<dynamic, dynamic>
    // (iOS NSDictionary → Map sem typo). Se vier num formato inesperado,
    // loga e segue sem crashar a stream.
    if (raw is! Map) {
      Logger.warn('workout_realtime.event_not_map', context: {'raw_type': raw.runtimeType.toString()});
      return;
    }
    final type = raw['type'];
    if (type is! String) {
      Logger.warn('workout_realtime.event_no_type', context: {'raw_keys': raw.keys.toList().toString()});
      return;
    }
    switch (type) {
      case 'bpm':
        // raw['value'] pode chegar como:
        //   - int (Swift Int → Dart int direto)
        //   - double (alguma plataforma vira NSNumber double)
        //   - String "85" (debug payload, hypothetical)
        // Cobrir os 3 com num parse defensivo.
        final rawValue = raw['value'];
        int? bpm;
        if (rawValue is num) {
          bpm = rawValue.round();
        } else if (rawValue is String) {
          bpm = int.tryParse(rawValue) ?? double.tryParse(rawValue)?.round();
        }
        if (bpm == null) {
          Logger.warn('workout_realtime.bpm_unparseable', context: {
            'value_type': rawValue?.runtimeType.toString() ?? 'null',
            'value': '$rawValue',
          });
        }
        _emitBpm(bpm);
        break;
      case 'state':
        final value = raw['value'] as String?;
        if (value == 'active') {
          _setState(WorkoutSessionState.active);
        } else if (value == 'paused') {
          _setState(WorkoutSessionState.paused);
        } else if (value == 'ended') {
          _setState(WorkoutSessionState.idle);
        }
        break;
      case 'warning':
        // Ex.: 'no_hr_source' — silencioso na UI por decisão de produto, mas
        // logado pra telemetria poder rastrear quantos users ficam sem fonte.
        Logger.warn('workout_realtime.warning', context: {
          'code': '${raw['code']}',
          'message': '${raw['message']}',
        });
        _emitBpm(null);
        break;
      case 'error':
        Logger.warn('workout_realtime.error', context: {
          'code': '${raw['code']}',
          'message': '${raw['message']}',
        });
        _emitBpm(null);
        break;
      default:
        Logger.warn('workout_realtime.unknown_type', context: {'type': type});
    }
  }

  void _emitBpm(int? value) {
    _latestBpm = value;
    if (!_bpmController.isClosed) _bpmController.add(value);
  }

  void _setState(WorkoutSessionState s) {
    if (_state == s) return;
    _state = s;
    if (!_sessionStateController.isClosed) _sessionStateController.add(s);
  }
}

final workoutRealtimeService = WorkoutRealtimeService();
