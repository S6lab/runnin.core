import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/theme_controller.dart';

/// Estado da sessão de workout. O serviço mantém uma máquina de estados
/// idempotente — start/pause/resume/stop não fazem nada se já estiverem
/// no estado correspondente.
enum WorkoutSessionState { idle, starting, active, paused, stopping }

/// Comando emitido pelo Watch via WCSession sendMessage. RunBloc traduz em
/// events do bloc (PauseRun, AbandonRun, StartRun com payload, etc).
class WatchCommand {
  final String action;          // 'pauseRun' | 'resumeRun' | 'abandonRun' | 'startRun'
  final Map<String, dynamic> payload; // raw extras: type, planSessionId, isPremium

  const WatchCommand({required this.action, this.payload = const {}});

  factory WatchCommand.fromMap(Map<dynamic, dynamic> map) => WatchCommand(
        action: (map['action'] as String?) ?? '',
        payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      );
}

/// Estado do pareamento + instalação do app companion no Apple Watch.
/// Emitido pelo plugin nativo iOS via evento `watch_status`. Consumido por
/// [RunBloc]/[active_run_page] pra renderizar:
///   - banner "Conecte um Apple Watch" (paired=false)
///   - banner "Instale o Runnin no Watch" (paired=true, installed=false)
///   - badge "via Watch" no chip BPM (reachable=true durante a corrida)
class WatchPairingStatus {
  final bool paired;
  final bool appInstalled;
  final bool reachable;

  const WatchPairingStatus({
    required this.paired,
    required this.appInstalled,
    required this.reachable,
  });

  static const unknown = WatchPairingStatus(
    paired: false, appInstalled: false, reachable: false,
  );

  factory WatchPairingStatus.fromMap(Map<dynamic, dynamic> map) =>
      WatchPairingStatus(
        paired: map['paired'] == true,
        appInstalled: map['appInstalled'] == true,
        reachable: map['reachable'] == true,
      );

  bool get isOptimal => paired && appInstalled && reachable;

  @override
  bool operator ==(Object other) =>
      other is WatchPairingStatus &&
      other.paired == paired &&
      other.appInstalled == appInstalled &&
      other.reachable == reachable;

  @override
  int get hashCode => Object.hash(paired, appInstalled, reachable);
}

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
  /// TF 75 Fase 1: total cumulativo de passos do Watch (HK stepCount sumQty
  /// da sessão). RunBloc usa pra detectar idle (0 passos em 60s) e dropar
  /// drift GPS cumulativo. Sem isso, GPS oscilando parado somava 500m falso.
  final _stepsController = StreamController<int>.broadcast();
  int? _latestSteps;
  /// TF 75 Fase 12: SpO2 (oxigenação) em %. Apple Watch Series 6+ tem
  /// oxímetro de pulso. Sample raro (~30-60s); UI mostra último valor.
  final _spo2Controller = StreamController<int>.broadcast();
  int? _latestSpo2;
  final _sessionStateController = StreamController<WorkoutSessionState>.broadcast();
  final _warningController = StreamController<String>.broadcast();
  final _watchStatusController = StreamController<WatchPairingStatus>.broadcast();
  WatchPairingStatus _latestWatchStatus = WatchPairingStatus.unknown;
  /// Comandos vindos do Watch via WCSession sendMessage. Payload tem `action`
  /// e opcionalmente outros campos (ex: action=startRun → type, planSessionId).
  /// RunBloc se inscreve e dispatcha events correspondentes.
  final _watchCommandController = StreamController<WatchCommand>.broadcast();
  /// Emite quando WCSession volta a reachable (flip false→true) durante uma
  /// corrida ativa. RunBloc consome pra forçar restart imediato da query de
  /// BPM em vez de esperar 15s de staleness.
  final _watchReconnectedController = StreamController<void>.broadcast();
  /// Emite quando o Watch app é reinstalado (`isWatchAppInstalled` flip
  /// false→true). O reinstall zera o cache `receivedApplicationContext` no
  /// Watch — todas as últimas pushes (today_session, run_state) são perdidas.
  /// main.dart consome pra disparar `watchTodaySessionPusher.pushToday()`
  /// novamente.
  final _watchAppInstalledController = StreamController<void>.broadcast();

  /// Snapshot da última sessão do dia empurrada. `updateApplicationContext`
  /// é single-value (dedup) — quando um push de run_state vem depois, o cache
  /// fica só com run_state e perde today_session. Reactivation do Watch lê
  /// só do último cache → SESSÃO DO DIA some. Solução: TODA push leva
  /// `today_session` junto, mesmo se o tipo principal for run_state.
  Map<String, dynamic>? _lastTodaySession;

  /// Stream de BPMs do wearable. Emite `null` quando a fonte fica indisponível
  /// (Watch desligado, permission revogada). UI fica em '—' silenciosamente.
  ///
  /// Replay-on-listen: cada novo listener recebe imediatamente o `_latestBpm`
  /// cacheado (se houver), pra não perder o último sample emitido antes do
  /// subscribe. Crítico pra evitar race entre `start()` e o listener inicial.
  ///
  /// Anexa o EventChannel proativamente no primeiro listen — antes ficava
  /// gated atrás de [start()] e qualquer subscriber que chegasse antes
  /// (caso comum em StreamBuilders e tests) perdia samples até start.
  Stream<int?> get bpmStream async* {
    _attachEventStream();
    if (_latestBpm != null) yield _latestBpm;
    yield* _bpmController.stream;
  }

  /// TF 75 Fase 1: total cumulativo de passos do Watch durante a sessão.
  /// Emite a cada ~5s (throttle no Watch). RunBloc mantém janela 60s pra
  /// detectar idle e descartar drift GPS.
  Stream<int> get stepsStream async* {
    _attachEventStream();
    if (_latestSteps != null) yield _latestSteps!;
    yield* _stepsController.stream;
  }

  /// TF 75 Fase 12: SpO2 (% oxigenação) do Apple Watch Series 6+.
  /// Replay-on-listen igual ao bpmStream.
  Stream<int> get spo2Stream async* {
    _attachEventStream();
    if (_latestSpo2 != null) yield _latestSpo2!;
    yield* _spo2Controller.stream;
  }

  /// Stream de warnings nativos (`no_hr_source`, `permission_denied`, etc).
  /// UI consome pra mostrar banner quando a fonte de BPM falha.
  Stream<String> get warningStream => _warningController.stream;

  /// Estados da sessão: idle → starting → active ↔ paused → stopping → idle.
  Stream<WorkoutSessionState> get sessionStateStream =>
      _sessionStateController.stream;

  /// Estado do pareamento + instalação do app companion no Apple Watch.
  /// Replay-on-listen igual ao bpmStream — UI que chega depois do primeiro
  /// evento ainda vê o status atual em vez de `unknown`.
  Stream<WatchPairingStatus> get watchStatusStream async* {
    _attachEventStream();
    yield _latestWatchStatus;
    yield* _watchStatusController.stream;
  }

  WatchPairingStatus get latestWatchStatus => _latestWatchStatus;

  /// Stream de comandos vindos do Watch (pauseRun/abandonRun/startRun/etc).
  /// RunBloc inscreve uma vez no init e dispatcha events correspondentes.
  Stream<WatchCommand> get watchCommandStream {
    _attachEventStream();
    return _watchCommandController.stream;
  }

  /// Stream que emite quando WCSession reconecta após drop (ver
  /// `_watchReconnectedController`). RunBloc usa pra forçar restart da
  /// query de BPM imediatamente em vez de esperar staleness expirar.
  Stream<void> get watchReconnectedStream {
    _attachEventStream();
    return _watchReconnectedController.stream;
  }

  /// Stream que emite quando o Watch app é reinstalado. main.dart usa pra
  /// re-empurrar today_session (e qualquer outro state) imediatamente.
  Stream<void> get watchAppInstalledStream {
    _attachEventStream();
    return _watchAppInstalledController.stream;
  }

  /// Empurra snapshot do RunState atual pro Watch via WCSession applicationContext.
  /// Idempotente — chamado pelo RunBloc a cada `_onTimerTick` (1Hz) durante
  /// active/paused. Payload é Map serializável (sem tipos custom).
  ///
  /// Auto-injeta `accentColor` (hex da skin atual do iPhone) e `textScale`
  /// (1.0 / 1.12 / 1.28) — caller não precisa passar; Watch usa accentColor
  /// pra colorir botões e textScale pra escalar fontes refletindo a pele +
  /// preferências de Configurações > Aparência.
  ///
  /// CRÍTICO: filtra entradas null do payload ANTES de mandar pro Swift.
  /// `WCSession.updateApplicationContext` exige property-list types puros —
  /// Map Dart com `null` vira `NSNull` em Swift, que faz a chamada lançar
  /// `NSInvalidArgumentException` e o push inteiro falha em silêncio. Era a
  /// causa do "Watch não muda de tela ao iniciar corrida" (paceMinKm=null
  /// antes do primeiro km).
  Future<void> pushRunState(Map<String, dynamic> payload) async {
    if (!_isSupported) return;
    try {
      final clean = <String, dynamic>{};
      payload.forEach((k, v) {
        if (v != null) clean[k] = v;
      });
      if (!clean.containsKey('accentColor')) {
        clean['accentColor'] = _hexFromColor(themeController.palette.primary);
      }
      if (!clean.containsKey('secondaryColor')) {
        // Watch usa pra colorir DIST/BPM (mesmo padrão do iPhone — palette.secondary).
        clean['secondaryColor'] = _hexFromColor(themeController.palette.secondary);
      }
      if (!clean.containsKey('textScale')) {
        clean['textScale'] = themeController.textScaleFactor;
      }
      // Captura today_session quando vier explícita; injeta em pushes
      // subsequentes pra ela não se perder no cache single-value do
      // applicationContext.
      // Importante: usa `payload` (original com nulls) em vez de `clean` (sanitizado)
      // pra detectar `session: null` corretamente — o sanitize remove keys com
      // null antes desse bloco, fazendo `clean['session']` parecer ausente.
      if (payload['type'] == 'today_session') {
        _lastTodaySession = {
          'type': 'today_session',
          'session': payload['session'], // pode ser null (sem sessão hoje)
        };
      } else if (_lastTodaySession != null &&
          _lastTodaySession!['session'] != null && // ← NÃO injeta NSNull
          !payload.containsKey('session') &&
          clean['type'] != 'today_session') {
        // Re-injeta today_session pra cada push (skin update, run_state, etc).
        // Watch.update(from:) ignora `session` quando type != 'today_session',
        // então passamos a session em campo dedicado `_attachedTodaySession`
        // que o Watch sabe ler como fallback. Pulamos quando session é null
        // — NSNull no payload faz `updateApplicationContext` lançar
        // "Payload contains unsupported type" e DERRUBA O PUSH INTEIRO.
        clean['_attachedTodaySession'] = _lastTodaySession!['session'];
      }
      await _methodChannel.invokeMethod('pushRunState', clean);
    } catch (_) {/* best-effort, plugin loga internamente */}
  }

  /// Converte Color → "#RRGGBB" (8-bit canais, sem alpha). Plugin nativo
  /// repassa direto pro Watch via applicationContext.
  String _hexFromColor(dynamic color) {
    // Evita import direto de dart:ui — themeController.palette.primary é
    // Color do Flutter; usamos .toARGB32() (substituto não-deprecado de .value)
    // pra extrair canais. Math em int — alocação zero.
    final v = (color as dynamic).toARGB32() as int;
    final r = (v >> 16) & 0xFF;
    final g = (v >> 8) & 0xFF;
    final b = v & 0xFF;
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

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

  /// Pede ao nativo pra recriar a `HKAnchoredObjectQuery` (iOS) ou recadastrar
  /// o callback de medição (Android) preservando a `HKWorkoutSession`/Workout
  /// em andamento. Caminho de resgate quando o stream BPM "morre em silêncio"
  /// — comum no HealthKit quando o Watch perde conexão por uns segundos. Chama
  /// `_methodChannel.invokeMethod('restart')`; o lado nativo deve preservar o
  /// anchor pra não duplicar amostras antigas. Idempotente — em estado idle/
  /// stopping é no-op.
  Future<void> restart() async {
    if (!_isSupported) return;
    if (_state == WorkoutSessionState.idle ||
        _state == WorkoutSessionState.stopping) {
      return;
    }
    try {
      await _methodChannel.invokeMethod('restart');
      Logger.info('workout_realtime.restart', context: const {'reason': 'stale_or_lost'});
    } on PlatformException catch (e, st) {
      // MissingPluginException é subclasse de PlatformException — sinaliza
      // que o nativo ainda não tem o handler `restart`. Não há tratamento
      // diferente além de logar: o flag de staleness + fallback poll já
      // cobrem o gap.
      if (e is MissingPluginException) {
        Logger.info('workout_realtime.restart_unsupported');
      } else {
        Logger.error('workout_realtime.restart_failed', e, st, {'code': e.code});
      }
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

    // TF 75 Fase 9: detached do método stop pra ficar disponível pra
    // chamadores externos (RunBloc no resume do app).
    // NÃO desliga o event stream — Watch comandos (startRun, pauseRun, etc)
    // E watch_status precisam continuar fluindo. Detachar aqui fazia o
    // Plugin Swift's onCancel disparar (eventSink = nil) e droppar TODOS
    // os eventos subsequentes silenciosamente — causa do "iniciar pelo
    // Watch funciona uma vez só" bug. EventChannel fica vivo pra sempre.
    _emitBpm(null);
  }

  /// TF 75 Fase 9: consulta o BPM nativo cacheado pelo Plugin iOS via WCSession.
  /// Usado quando o app reataches do background — Dart engine pode ter
  /// suspendido, mas o handler Swift do WCSession continua rodando e cacheia
  /// o último BPM recebido do Watch. Retorna null se cache vazio/>30s velho.
  Future<int?> getLastCachedBpm() async {
    try {
      final res = await _methodChannel.invokeMethod<Map>('getLastCachedBpm');
      if (res == null) return null;
      final bpm = res['bpm'] as int? ?? 0;
      final ageMs = res['ageMs'] as int? ?? 999999;
      if (bpm <= 0 || ageMs > 30000) return null;
      return bpm;
    } catch (_) {
      return null;
    }
  }

  void _attachEventStream() {
    _eventSub ??= _eventChannel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e, StackTrace st) {
        Logger.error('workout_realtime.event_stream_error', e, st);
      },
    );
  }

  void _detachEventStream() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  /// Test seam: simula um evento como se viesse do EventChannel nativo,
  /// sem depender do binding global (que causa leak entre instâncias).
  /// Em produção, [_onEvent] é alimentado por [_attachEventStream] / o canal
  /// nativo iOS/Android.
  @visibleForTesting
  void debugSimulateEvent(Map<dynamic, dynamic> raw) => _onEvent(raw);

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
      case 'steps':
        final rawValue = raw['value'];
        int? steps;
        if (rawValue is num) {
          steps = rawValue.round();
        } else if (rawValue is String) {
          steps = int.tryParse(rawValue);
        }
        if (steps != null && steps >= 0) {
          _latestSteps = steps;
          _stepsController.add(steps);
        }
        break;
      case 'spo2':
        final rawValue = raw['value'];
        int? pct;
        if (rawValue is num) {
          pct = rawValue.round();
        } else if (rawValue is String) {
          pct = int.tryParse(rawValue);
        }
        if (pct != null && pct >= 50 && pct <= 100) {
          _latestSpo2 = pct;
          _spo2Controller.add(pct);
        }
        break;
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
        // Ex.: 'no_hr_source' — emitido após 8s sem samples; UI consome
        // warningStream pra surfar banner que ajuda usuário a entender
        // (pedir Watch / verificar permission). Antes era só log.
        final code = '${raw['code']}';
        Logger.warn('workout_realtime.warning', context: {
          'code': code,
          'message': '${raw['message']}',
        });
        if (!_warningController.isClosed) _warningController.add(code);
        _emitBpm(null);
        break;
      case 'error':
        final code = '${raw['code']}';
        Logger.warn('workout_realtime.error', context: {
          'code': code,
          'message': '${raw['message']}',
        });
        if (!_warningController.isClosed) _warningController.add(code);
        _emitBpm(null);
        break;
      case 'watch_status':
        // Emitido pelo plugin iOS a cada mudança de pareamento, instalação
        // ou reachability. UI usa pra mostrar banner pre-run + badge no chip.
        final status = WatchPairingStatus.fromMap(raw);
        if (status != _latestWatchStatus) {
          _latestWatchStatus = status;
          if (!_watchStatusController.isClosed) {
            _watchStatusController.add(status);
          }
        }
        break;
      case 'watch_command':
        // Comando vindo do Watch (sendMessage WCSession). RunBloc traduz
        // em events do bloc — pausa/abandona/inicia corrida.
        final cmd = WatchCommand.fromMap(raw);
        if (cmd.action.isNotEmpty && !_watchCommandController.isClosed) {
          _watchCommandController.add(cmd);
        }
        break;
      case 'watch_reconnected':
        // Emitido pelo plugin iOS quando WCSession.isReachable flip false→true.
        // RunBloc consome pra restart imediato da query de BPM (sem esperar
        // os 15s de staleness — gap visível pro user).
        if (!_watchReconnectedController.isClosed) {
          _watchReconnectedController.add(null);
        }
        break;
      case 'watch_app_installed':
        // Emitido pelo plugin iOS quando isWatchAppInstalled flip false→true
        // (Watch app reinstalado pelo user OU pelo dev em build). O cache de
        // applicationContext do Watch é zerado nessa transição, então
        // qualquer push anterior (today_session) é perdido. main.dart re-empurra.
        if (!_watchAppInstalledController.isClosed) {
          _watchAppInstalledController.add(null);
        }
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

  /// Limpa subs e fecha controllers. Usado nos testes pra evitar leak entre
  /// instâncias (EventChannel é global por nome de canal). Em produção o
  /// service vive pelo app inteiro — singleton top-level — então `dispose`
  /// só é chamado em rotas de cleanup específicas / testes.
  Future<void> dispose() async {
    _detachEventStream();
    if (!_bpmController.isClosed) await _bpmController.close();
    if (!_sessionStateController.isClosed) await _sessionStateController.close();
    if (!_warningController.isClosed) await _warningController.close();
  }
}

final workoutRealtimeService = WorkoutRealtimeService();
