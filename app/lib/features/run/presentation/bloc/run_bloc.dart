import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnin/core/analytics/analytics_service.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/audio/telemetry_tts.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/run/data/datasources/run_local_datasource.dart';
import 'package:runnin/core/debug/mock_gps_service.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/notifications/run_bg_notification_service.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/data/audio_session_keepalive.dart';
import 'package:runnin/features/run/data/live_run_coach_session.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/coach_live/data/coach_context_manager.dart';
import 'package:runnin/features/location_weather/data/location_weather_controller.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

// ── Events ──────────────────────────────────────────────────────────────────
abstract class RunEvent {}

class StartRun extends RunEvent {
  final String type;
  final String? targetPace;
  final String? targetDistance;
  /// Preferências de alerta do coach (do prep page).
  /// Keys: kmAlert, paceOutOfRange, highBpm, kmSplits, motivation.
  /// Defaults true (exceto kmSplits) caso o caller não passe — comportamento
  /// anterior era hardcode sempre-on, então default-on mantém retro-compat.
  final Map<String, bool>? alertPrefs;
  /// ID da sessão do plano que essa run está executando. Quando setado,
  /// server marca a sessão como "feita" ao completar a run. Null = corrida
  /// livre não vinculada a sessão planejada.
  final String? planSessionId;
  /// True = abre LiveRunCoachSession (Gemini Live, voz natural).
  /// False = pula a sessão Live e usa TelemetryTts on-device pra falar
  /// pace/tempo a cada km (modo FREEMIUM). Null = fallback pra true
  /// (mantém comportamento anterior caso caller esqueça de passar).
  final bool? isPremium;
  /// TF 77 F3: origem do start. 'watch' quando user iniciou pelo Watch,
  /// 'iphone' (default) quando UI iPhone. LA não deve iniciar quando origem
  /// é Watch — Watch já cobre o display, LA mirroreia como banner "Abrir
  /// no iPhone" sobrepondo a ActiveRunScreen.
  final String? startSource;
  StartRun({
    required this.type,
    this.targetPace,
    this.targetDistance,
    this.alertPrefs,
    this.planSessionId,
    this.isPremium,
    this.startSource,
  });
}

class _GpsUpdate extends RunEvent {
  final Position pos;
  _GpsUpdate(this.pos);
}

class _TimerTick extends RunEvent {}

/// Tick periódico de 30s para snapshot sincronizado {bpm, pace, distância}
/// na telemetryTimeline. Fix TF 59 — Issue #6 do plano.
class _TelemetryTick extends RunEvent {}

class _CoachChunk extends RunEvent {
  final CoachCue cue;
  _CoachChunk(this.cue);
}

class CompleteRun extends RunEvent {}

class AbandonRun extends RunEvent {}

class PauseRun extends RunEvent {}

class ResumeRun extends RunEvent {}

/// Interno: disparado pelo timer de stall (30s sem deslocamento). Pausa a
/// run e marca o flag pra UI mostrar o dialog de continuar/encerrar.
class _NoMovementDetected extends RunEvent {}

/// Tick interno disparado por cada sample BPM emitido pelo
/// [WorkoutRealtimeService] (1Hz quando há Watch/Wear OS pareado). Null
/// quando a fonte some (Watch desligado, permission revogada).
///
/// [fallback]=true indica que o sample veio do polling do healthSyncService
/// (HealthKit/Health Connect direto) em vez do stream nativo de workout.
/// Coach cue `high_bpm` só dispara em modo realtime — fallback tem
/// latência alta (15s+) e pode levar a alertas atrasados.
/// TF 75 Fase 12: SpO2 sample do Watch via WCSession (oxigenação %).
class _Spo2Tick extends RunEvent {
  final int pct;
  _Spo2Tick(this.pct);
}

class _BpmTick extends RunEvent {
  final int? value;
  final bool fallback;
  _BpmTick(this.value, {this.fallback = false});
}

/// Mudança no pareamento/instalação/reachability do Apple Watch companion.
/// Vem do plugin nativo via `workoutRealtimeService.watchStatusStream`.
class _WatchStatusChanged extends RunEvent {
  final WatchPairingStatus status;
  _WatchStatusChanged(this.status);
}

/// Limpa o flag do dialog de "parado" (ex: ao escolher continuar/encerrar).
class DismissNoMovementPrompt extends RunEvent {}

/// Push-to-talk: abre a janela de fala com o coach (botão "Coach" pressionado).
/// Streama o mic pra sessão Live já aberta; o coach responde e volta a narrar.
class CoachTalkStart extends RunEvent {}

/// Fecha a janela de fala (botão solto) → o coach responde.
class CoachTalkStop extends RunEvent {}

// ── State ────────────────────────────────────────────────────────────────────
enum RunStatus { idle, starting, active, paused, completing, completed, error }

/// Estágios de "vivacidade" do stream BPM. Permite à UI mostrar avisos
/// intermediários em vez de cair direto pra "desconectado" quando a fonte
/// apenas atrasa.
///
/// Transições no [RunBloc]:
///   - chega sample com value>0     → fresh
///   - 15s sem sample                → stale (UI: último valor + "?")
///   - 45s sem sample                → lost  (UI: "—")
///   - sample nulo / source caiu     → lost imediato
enum BpmStaleness { fresh, stale, lost }

/// Tick 30s da corrida com bpm + pace + distância JUNTOS no mesmo instante.
/// Cobre o gap das splits (1x/km) — picos curtos de BPM (5-10s) não somem na
/// média do km, e o coach in-run consegue ler "como foi os últimos 500m".
class TelemetryPoint {
  final int tMs;           // ms desde startedAt
  final double distM;
  final int? bpm;
  final int? paceSec;      // sec/km dos últimos ~50m
  const TelemetryPoint({
    required this.tMs,
    required this.distM,
    this.bpm,
    this.paceSec,
  });

  Map<String, dynamic> toJson() => {
        'tMs': tMs,
        'distM': distM,
        if (bpm != null) 'bpm': bpm,
        if (paceSec != null) 'paceSec': paceSec,
      };
}

class RunState {
  final RunStatus status;
  final String? runId;
  final List<GpsPoint> points;
  final double distanceM;
  final int elapsedS;
  final double? currentPaceMinKm;
  final String? runType;
  final String? targetPace;
  final String? targetDistance;
  final String? coachLiveMessage;
  final String? coachAudioBase64;
  final String? coachAudioMimeType;
  final String? error;
  final Run? completedRun;
  /// Splits por km já fechados durante a run em andamento. Cada item é
  /// um KmSplit completo (pace agregado, duração, velocidade média).
  /// UI consome em vez do `state.formattedPace` global. LLM recebe
  /// últimos N como `recentSplits` no evento `km_analysis`.
  final List<KmSplit> splits;
  /// True quando a detecção de "parado" (sem deslocamento em 30s) pausou a
  /// run e a UI deve exibir o dialog de continuar/encerrar.
  final bool noMovementPrompt;
  /// BPM "ao vivo" do wearable durante a corrida ativa. Alimentado pelo
  /// [WorkoutRealtimeService] (HKWorkoutSession iOS / HealthServicesClient
  /// Android) — null sem wearable conectado / fora da run.
  final int? currentBpm;
  /// BPM máximo visto durante a corrida atual. Reset em _onStart.
  final int? maxBpmSeen;
  /// Vivacidade do stream BPM — `fresh` (sample recente), `stale` (sem sample
  /// há 15s, ainda mostra último valor com aviso), `lost` (sem sample há
  /// 45s, UI mostra "—"). Substituiu o antigo `bpmSourceActive` boolean —
  /// continua exposto como getter pra back-compat com a UI antiga e o coach
  /// cue `high_bpm`.
  final BpmStaleness bpmStaleness;
  /// Origem do sample BPM ativo: 'realtime' (WorkoutRealtimeService, Watch/
  /// Wear OS pareado), 'fallback' (polling do HealthKit/Health Connect quando
  /// realtime não inicia), ou 'none' (sem nenhuma fonte). UI mostra ícone
  /// diferente por fonte e o copy do chip ("BPM · 142" vs "BPM · sem fonte").
  final String bpmSource;
  /// Pareamento + instalação do app companion no Apple Watch (iOS).
  /// Atualizado pelo plugin nativo via stream `watchStatusStream`. UI usa
  /// pra renderizar banner pre-run + badge "via Watch" no chip BPM.
  /// `null` em plataformas sem Watch (Android, web).
  final WatchPairingStatus? watchStatus;
  /// Telemetria sincronizada a cada 30s {bpm, pace, distância}. Acumula
  /// durante a run, persiste no completeRun pra alimentar o relatório
  /// e a revisão semanal com a curva real.
  final List<TelemetryPoint> telemetryTimeline;
  /// TF 75 Fase 12: SpO2 (oxigenação) em %. Apple Watch Series 6+ tem
  /// oxímetro de pulso. Null sem fonte; sample raro (~30-60s).
  final int? currentSpo2;

  const RunState({
    this.status = RunStatus.idle,
    this.runId,
    this.points = const [],
    this.distanceM = 0,
    this.elapsedS = 0,
    this.currentPaceMinKm,
    this.runType,
    this.targetPace,
    this.targetDistance,
    this.coachLiveMessage,
    this.coachAudioBase64,
    this.coachAudioMimeType,
    this.error,
    this.completedRun,
    this.splits = const [],
    this.noMovementPrompt = false,
    this.currentBpm,
    this.maxBpmSeen,
    this.bpmStaleness = BpmStaleness.lost,
    this.bpmSource = 'none',
    this.watchStatus,
    this.telemetryTimeline = const [],
    this.currentSpo2,
  });

  /// Compat com a UI antiga e o gating de coach cue `high_bpm`: ativo quando
  /// estamos em fresh ou stale (último sample relativamente recente). Só false
  /// em `lost` — quando UI deve mostrar "—" e o coach não disparar cue.
  bool get bpmSourceActive => bpmStaleness != BpmStaleness.lost;

  RunState copyWith({
    RunStatus? status,
    String? runId,
    List<GpsPoint>? points,
    double? distanceM,
    int? elapsedS,
    double? currentPaceMinKm,
    String? runType,
    String? targetPace,
    String? targetDistance,
    String? coachLiveMessage,
    String? coachAudioBase64,
    String? coachAudioMimeType,
    String? error,
    Run? completedRun,
    List<KmSplit>? splits,
    bool? noMovementPrompt,
    int? currentBpm,
    int? maxBpmSeen,
    BpmStaleness? bpmStaleness,
    String? bpmSource,
    WatchPairingStatus? watchStatus,
    List<TelemetryPoint>? telemetryTimeline,
    int? currentSpo2,
  }) => RunState(
    status: status ?? this.status,
    runId: runId ?? this.runId,
    points: points ?? this.points,
    distanceM: distanceM ?? this.distanceM,
    elapsedS: elapsedS ?? this.elapsedS,
    currentPaceMinKm: currentPaceMinKm ?? this.currentPaceMinKm,
    runType: runType ?? this.runType,
    targetPace: targetPace ?? this.targetPace,
    targetDistance: targetDistance ?? this.targetDistance,
    coachLiveMessage: coachLiveMessage ?? this.coachLiveMessage,
    coachAudioBase64: coachAudioBase64 ?? this.coachAudioBase64,
    coachAudioMimeType: coachAudioMimeType ?? this.coachAudioMimeType,
    error: error ?? this.error,
    completedRun: completedRun ?? this.completedRun,
    splits: splits ?? this.splits,
    noMovementPrompt: noMovementPrompt ?? this.noMovementPrompt,
    currentBpm: currentBpm ?? this.currentBpm,
    maxBpmSeen: maxBpmSeen ?? this.maxBpmSeen,
    bpmStaleness: bpmStaleness ?? this.bpmStaleness,
    bpmSource: bpmSource ?? this.bpmSource,
    watchStatus: watchStatus ?? this.watchStatus,
    telemetryTimeline: telemetryTimeline ?? this.telemetryTimeline,
    currentSpo2: currentSpo2 ?? this.currentSpo2,
  );

  String get formattedDistance => '${(distanceM / 1000).toStringAsFixed(2)}km';
  String get formattedElapsed {
    final m = elapsedS ~/ 60;
    final s = elapsedS % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (currentPaceMinKm == null) return '--:--';
    final min = currentPaceMinKm!.floor();
    final sec = ((currentPaceMinKm! - min) * 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

// ── BLoC ─────────────────────────────────────────────────────────────────────
class RunBloc extends Bloc<RunEvent, RunState> with WidgetsBindingObserver {
  final _remote = RunRemoteDatasource();
  final _userRemote = UserRemoteDatasource();
  // TF 69: fallback HTTP /coach/message quando _coachSession.isOpen == false.
  // Antes, premium ficava em silêncio quando Live caía mid-run; agora o cue
  // sai via server (templates ativos ou Flash LLM + Live TTS server-side).
  final _coachRemote = RunCoachRemoteDatasource();
  // Contexto do coach sobrevive à rotação/queda da sessão Live (source-of-truth
  // do histórico curto pra reinjetar como preamble quando a sessão é reciclada).
  final _coachCtx = CoachContextManager();
  // Sessão Gemini Live efêmera/rotacional: rotaciona em transições naturais
  // pra evitar acúmulo de áudio no histórico interno do socket (que degradava
  // a voz por volta do km 3 no modelo native-audio).
  // Não-final pra TF 71 Fase -2: quando user inicia nova run sem completar
  // a anterior, recriamos o objeto pra cortar reconnects órfãos consumindo
  // token/generation. `close()` seta _disposed=true e bloqueia reuso, então
  // precisa nova instância.
  late LiveRunCoachSession _coachSession = LiveRunCoachSession(
    contextManager: _coachCtx,
  );
  StreamSubscription<String>? _coachTranscriptSub;
  // Quando trigger natural cai durante push-to-talk, marca pra rotacionar
  // assim que o user soltar o botão (evita cortar a fala do user).
  String? _pendingRotationTrigger;
  final _local = RunLocalDatasource();
  final _planRemote = PlanRemoteDatasource();

  StreamSubscription<Position>? _gpsSub;
  /// Web only: timer de polling pra getCurrentPosition (browser nao
  /// emite stream sem movimento real). Native usa _gpsSub direto.
  Timer? _gpsPollTimer;
  Timer? _timer;
  Timer? _flushTimer;
  /// Snapshot {bpm, pace, distância} a cada 30s pra telemetryTimeline.
  /// Fix TF 59: alinha temporalmente os 3 sinais (BPM/GPS streams chegam
  /// dessincronizados) e permite coach ler "como foi os últimos 500m".
  Timer? _telemetryTickTimer;
  /// Safety: a cada 30s checa se a sessão Live atingiu o threshold de
  /// idade pra rotação. Sem isso a rotação só acontece em km_reached/
  /// segment_start/segment_end — e em runs lentas (ou pace estável sem
  /// transição de segmento) a sessão estoura o cap implícito de ~10min
  /// do Gemini Live API e cai com code 1011. Já vimos esse padrão em prod.
  Timer? _coachRotationSafetyTimer;
  int _pendingFlushCount = 0;
  int _lastCoachKm = 0;
  /// Timestamp (s desde start da run) em que o último km foi cruzado.
  /// Usado pra calcular kmDurationS = elapsedS - _lastKmStartElapsedS no
  /// evento km_reached. Coach reporta "1 km em X min" (duração do km).
  int _lastKmStartElapsedS = 0;

  /// ID da sessão planejada da run atual. Server resolve a sessão por
  /// esse id; client mantém pra mandar em todo cue (server cacheia).
  String? _planSessionId;
  /// Cache dos segments da PlanSession atual, normalizados (kmStart,
  /// kmEnd, índice estável). Vazio quando não há plano OU sessão sem
  /// executionSegments.
  List<PlanSegment> _segments = const [];
  /// Índice do segment ativo (-1 = ainda não entrou em segment_0).
  /// Atualiza em _onGpsUpdate quando distância cruza kmStart de outro.
  int _currentSegmentIdx = -1;

  /// Distância alvo da sessão planejada (metros). Setado em _loadPlanSession
  /// a partir de PlanSession.distanceKm; null quando run é livre. Usado
  /// pelo cue `goal_reached`: quando o user passa do alvo, o coach avisa
  /// "sua sessão termina aqui" e oferece continuar (sem auto-complete).
  double? _plannedDistanceM;
  /// One-shot: garante que `goal_reached` dispare 1x por run mesmo se o
  /// user continuar correndo passado o alvo (esperado — coach disse "se
  /// quiser continuar, eu sigo"). Reset no _onStart.
  bool _goalReachedFired = false;

  /// Janela da saudação inicial: até este timestamp (ms) os cues de
  /// `/coach/message` são suprimidos pra NÃO tocarem por cima da saudação
  /// (Live) — evita "dois coaches" no início. A saudação já anuncia a sessão.
  int _suppressCuesUntilMs = 0;

  /// TF 75 Fase 1: true se Watch está conectado E reportou 0 passos nos
  /// últimos 60s. Usado pra droppar drift GPS cumulativo (pace falso ~5min/km
  /// gerado por GPS oscilando in place enganava o gate de pace anterior).
  ///
  /// Quando Watch não está conectado (sem entries no buffer), retorna null
  /// → fallback no gate de pace tradicional.
  bool? _isStepIdle60s() {
    if (_stepsBuf.length < 2) return null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final recent = _stepsBuf.where((e) => nowMs - e.ts <= _stepsIdleWindowMs);
    if (recent.length < 2) return null;
    final first = recent.first;
    final last = recent.last;
    final dt = last.ts - first.ts;
    if (dt < 30000) return null; // janela ainda incompleta
    return last.total - first.total == 0;
  }

  /// TF 77 F3: setado no _onStart a partir do StartRun.startSource. Quando
  /// 'watch', LA é bloqueada (Watch já cobre display).
  String? _startSource;

  /// TF 71 Fase -3: ring buffer da distância aceita nos últimos 60s. Per-point
  /// gate (TF 70) ainda deixava drift cumulativo passar — pontos isolados
  /// passavam, mas o conjunto somava pace de caminhada arrastando-se no lugar.
  /// Aqui gateamos por agregado: se pace na janela > 12 min/km, descartamos
  /// o último delta (drift cumulativo confirmado).
  final List<({int ts, double dist})> _gpsDriftWindow = [];
  static const int _driftWindowMs = 60000;
  static const double _driftMaxPaceMinKm = 12.0;

  /// True = abre Gemini Live (premium). False = só TTS on-device a cada km
  /// (freemium). Setado em [_onStart] a partir de [StartRun.isPremium];
  /// default true mantém comportamento anterior pra qualquer caller antigo.
  bool _isPremium = true;

  // Preferências de alerta do user (set em _onStart via StartRun.alertPrefs).
  // Defaults conservadores: tudo on exceto kmSplits (mais ruidoso).
  Map<String, bool> _alertPrefs = const {
    'kmAlert': true,
    'paceOutOfRange': true,
    'highBpm': true,
    'kmSplits': false,
    'motivation': true,
  };
  // Cooldown por tipo: timestamp do último cue daquele tipo (ms). Sem
  // isso, pace_alert disparava em CADA poll GPS (5s) quando user fora
  // do range — inundava o coach. 60s entre cues iguais é razoável.
  final Map<String, int> _lastCueAt = {};

  // Regra canônica de presença do coach: ele DEVE falar com o user
  // a cada 500m OU a cada 4min, o que vier primeiro. Trackers abaixo
  // são atualizados após qualquer fala do coach (independente do
  // evento) — assim qualquer cue zera os dois contadores.
  int _lastCoachSpeechAtMs = 0;
  double _lastCoachSpeechDistanceM = 0;
  static const _checkInDistanceM = 500.0;
  static const _checkInIdleSeconds = 240; // 4 min
  Timer? _motivationTimer;

  /// TF 75 Fase 3: cooldown global entre QUALQUER cue. Sem isso, check_in
  /// (500m) + km_reached + segment_start podiam disparar no mesmo ciclo GPS
  /// — Eduardo ouviu 2-3 cues sobrepostos.
  ///
  /// TF 77 F2: era 4s, insuficiente — cues ainda colidiam (Gemini Live
  /// tem ~5-8s de áudio por turn). Subido pra 8s + agora INCLUI pre_run
  /// (saudação respeita) pra evitar 2x saudação no race Watch+iPhone.
  int _lastAnyCoachCueAtMs = 0;
  static const _globalCueCooldownS = 8;
  /// Cue `km_analysis` agendado pra ~10s depois de cada km_reached.
  /// Cancelado se outro km cruza antes (rare) OU se user pausa/abandona —
  /// evita análise de km já irrelevante (ex: user pausou logo após km 3,
  /// análise sairia 10s no pause).
  Timer? _scheduledAnalysis;
  /// One-shot: dispara em ~30s pra checar se o user moveu o suficiente desde
  /// o START. Se distância < 5m E houve pelo menos 1 fix GPS, manda um
  /// `no_movement` cue ao coach (disclaimer gentil). Cancelado em
  /// pause/abandon/complete.
  Timer? _stallCheckTimer;
  bool _stallCueFired = false;

  // BPM realtime (workout_realtime_service). Subscription ativa durante
  // active+paused; cancela no complete/abandon. Samples acumulados por km
  // pra calcular kmAvgBpm que vai pro coach cue km_reached. _userMaxBpm
  // carregado em _onStart do profile pra gatear o cue high_bpm.
  StreamSubscription<int?>? _bpmSub;
  final List<int> _kmBpmSamples = [];
  int? _userMaxBpm;
  /// TF 75 Fase 1: subscription pro stepsStream do Watch (push via WCSession).
  /// Buffer de últimos N samples [(ts, totalSteps)] alimenta o gate idle
  /// no _onGpsUpdate.
  StreamSubscription<int>? _stepsSub;
  final List<({int ts, int total})> _stepsBuf = [];
  static const int _stepsIdleWindowMs = 60000;
  /// TF 75 Fase 12: SpO2 subscription.
  StreamSubscription<int>? _spo2Sub;
  /// Subscription pro watch_status do plugin nativo iOS. Ativa pro tempo
  /// todo (não só durante corrida) — a pre-run page também precisa do estado
  /// pra mostrar banner "Instale Runnin no Watch".
  StreamSubscription<WatchPairingStatus>? _watchStatusSub;
  /// Subscription pra comandos vindos do Watch (sendMessage). Watch user pode
  /// pausar/abandonar a corrida via slide-to-confirm na ActiveRunScreen, ou
  /// iniciar uma corrida nova via tap na PreRunScreen.
  StreamSubscription<WatchCommand>? _watchCommandSub;
  /// Subscription pra evento `watch_reconnected` (WCSession.isReachable flip
  /// false→true). Usa pra force-restart da query de BPM em vez de esperar
  /// o timer de staleness expirar (15s) — reduz gap visível de BPM live.
  StreamSubscription<void>? _watchReconnectedSub;

  // Lifecycle: true quando o app está em background (paused/inactive/hidden).
  // Usado pra suprimir TTS/voice em bg (não brigar com Spotify) e pra logger.
  bool _appInBackground = false;
  bool _observerRegistered = false;
  // Wall-clock (ms) do início da run ativa. Fonte da verdade pra elapsedS
  // — o tick de 1Hz só dispara re-render UI, o valor real é `now - start
  // - paused`. Sem isso o contador incremental driftava em bg (iOS suspende
  // o Dart isolate parcialmente — alguns ticks rodam, outros não, e o
  // catch-up no resume dobrava a contagem).
  int? _startedAtMs;
  // Tempo total (ms) que a run passou em paused, acumulado entre ciclos
  // pause↔resume. Subtraído do diff wall-clock pra elapsedS refletir só
  // tempo ATIVO.
  int _pausedTotalMs = 0;
  // Wall-clock (ms) em que a run entrou em paused. Null quando ativa ou
  // antes da primeira pausa. Em resume, somamos (now - this) em
  // _pausedTotalMs e zeramos.
  int? _pauseStartMs;

  /// Settings de localização específicas pra Run ativa. iOS exige
  /// `allowBackgroundLocationUpdates` + `pauseLocationUpdatesAutomatically:
  /// false` + `activityType: .fitness` pra GPS continuar quando o app
  /// minimiza (sem isso, Apple suspende em ~10s e o app trava ao voltar).
  /// Android usa ForegroundNotificationConfig pra o service não ser morto
  /// pelo doze mode. Web: sem suporte de background, usa settings simples.
  LocationSettings _runLocationSettings() {
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'runnin · corrida em andamento',
          notificationText:
              'Mantemos o GPS ativo pra preservar seu trace mesmo com a tela bloqueada.',
          enableWakeLock: true,
        ),
      );
    }
    // Fallback (web, desktop sem perfil específico).
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  // Native: GPS preciso, rejeita pontos ruins.
  // Web: browser usa WiFi/IP triangulation com accuracy 100-5000m+ —
  // se rejeitarmos com base no native threshold, mapa nunca abre.
  static final double _accuracyThreshold = kIsWeb ? 5000.0 : 15.0;
  static final double _displayAccuracyThreshold = kIsWeb ? 10000.0 : 150.0;
  static const stationaryDistanceThresholdM = 10.0;
  static const _flushBatchSize = 30;
  static const _flushIntervalS = 30;

  RunBloc() : super(const RunState()) {
    // Inscreve no stream de pareamento do Watch — ativo o ciclo de vida
    // todo do bloc (não só durante corrida). Pre-run page consome via
    // BlocBuilder pra renderizar banner "Conecte um Watch" / "Instale o app
    // no Watch". O plugin nativo emite quando o WCSession activate + a cada
    // mudança de pareamento/instalação/reachability.
    _watchStatusSub = workoutRealtimeService.watchStatusStream.listen(
      (status) {
        if (!isClosed) add(_WatchStatusChanged(status));
        // TF 70: informa o bg notif service que Watch está ativo. Suprime
        // o fallback de UNLocalNotification que mirroreava pro Watch como
        // "Abrir no iPhone" (cenário do teste TF 69 do Eduardo: 2 notifs
        // sobrepondo). Live Activity (iPhone) + Watch ActiveRunScreen
        // cobrem o display sem precisar de local notif.
        runBgNotificationService.setWatchHandlesDisplay(status.isOptimal);
      },
    );
    on<_WatchStatusChanged>(
      (e, emit) => emit(state.copyWith(watchStatus: e.status)),
    );
    // Comandos do Watch (PreRunScreen → startRun, ActiveRunScreen → pause/abandon).
    // Mapeia pra events do bloc — Watch nunca despacha direto pra UI.
    _watchCommandSub = workoutRealtimeService.watchCommandStream.listen(
      (cmd) {
        if (isClosed) return;
        switch (cmd.action) {
          case 'pauseRun':
            if (state.status == RunStatus.active) add(PauseRun());
            break;
          case 'resumeRun':
            if (state.status == RunStatus.paused) add(ResumeRun());
            break;
          case 'abandonRun':
            add(AbandonRun());
            break;
          case 'completeRun':
            // Watch tocou PARAR/encerrar → COMPLETE (salva + navega pra
            // /report). Diferente de abandonRun (cancela sem salvar).
            // Aceita só quando ativa ou pausada — outros estados ignora.
            if (state.status == RunStatus.active ||
                state.status == RunStatus.paused) {
              add(CompleteRun());
            }
            break;
          case 'acknowledgeComplete':
            // User tocou OK na RunCompletedScreen do Watch. Empurra status=idle
            // pra ele voltar ao TypeSelector (a UI do Watch já transicionou
            // localmente; este push só confirma o estado canônico).
            _pushStatusToWatch('idle');
            break;
          case 'startRun':
            // Watch só pode iniciar quando idle (já tem corrida ativa? ignora).
            if (state.status == RunStatus.idle ||
                state.status == RunStatus.completed) {
              final p = cmd.payload;
              add(StartRun(
                type: (p['type'] as String?) ?? 'Free Run',
                isPremium: p['isPremium'] == true,
                planSessionId: p['planSessionId'] as String?,
                // TF 77 F3: marca origem pra LA não iniciar com Watch ativo.
                startSource: 'watch',
              ));
            }
            break;
        }
      },
    );
    // Watch reconectou (reachability flip false→true) — força restart imediato
    // da query nativa de BPM. Sem isso, user vê BPM "—" por até 15s após
    // reconnect (timer de staleness expirar). Idempotente — restart() já é
    // safe pra chamar quando query está active.
    _watchReconnectedSub = workoutRealtimeService.watchReconnectedStream.listen(
      (_) {
        if (isClosed) return;
        if (state.status != RunStatus.active) return;
        Logger.info('run.bpm.watch_reconnected_restart');
        unawaited(workoutRealtimeService.restart());
      },
    );
    on<StartRun>(_onStart);
    on<_GpsUpdate>(_onGpsUpdate);
    on<_TimerTick>(_onTimerTick);
    on<_CoachChunk>(_onCoachChunk);
    on<CompleteRun>(_onComplete);
    on<AbandonRun>(_onAbandon);
    on<PauseRun>(_onPause);
    on<ResumeRun>(_onResume);
    on<_NoMovementDetected>(_onNoMovementDetected);
    on<_BpmTick>(_onBpmTick);
    on<_Spo2Tick>((e, emit) => emit(state.copyWith(currentSpo2: e.pct)));
    on<_TelemetryTick>(_onTelemetryTick);
    on<DismissNoMovementPrompt>(
      (e, emit) => emit(state.copyWith(noMovementPrompt: false)),
    );
    on<CoachTalkStart>((e, emit) => unawaited(_coachSession.startTalk()));
    on<CoachTalkStop>((e, emit) async {
      await _coachSession.stopTalk();
      final pending = _pendingRotationTrigger;
      if (pending != null) {
        _pendingRotationTrigger = null;
        unawaited(_coachSession.rotateSession(reason: 'deferred_$pending'));
      }
    });
    _local.init();
  }

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
    // Push otimista status=active pro Watch IMEDIATAMENTE — antes mesmo
    // de createRun ou checks de GPS. User pediu transição instantânea no
    // Watch quando inicia pelo iPhone. Se algo falhar abaixo, status=idle
    // é re-empurrado por _onAbandon/error.
    unawaited(workoutRealtimeService.pushRunState({
      'type': 'run_state',
      'status': 'active',
      'elapsedS': 0,
      'distanceM': 0,
      'paceMinKm': 0,
      'bpm': 0,
      'caloriesKcal': 0,
      'elevationM': 0,
      'runType': event.type,
      'splits': const [],
    }));

    // Consolida prefs: prioridade evento > profile > defaults. Sem isso,
    // _alertPrefs ficava nos defaults hardcoded e ignorava o que o user
    // selecionou no prep page. Fetch de profile é best-effort com
    // timeout curto pra não atrasar o start.
    if (event.alertPrefs != null) {
      _alertPrefs = {..._alertPrefs, ...event.alertPrefs!};
    } else {
      try {
        final profile = await _userRemote.getMe().timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
        final saved = profile?.preRunAlerts;
        if (saved != null && saved.isNotEmpty) {
          final merged = <String, bool>{..._alertPrefs};
          for (final e in saved.entries) {
            if (merged.containsKey(e.key)) merged[e.key] = e.value;
          }
          _alertPrefs = merged;
        }
        // maxBpm é o threshold pro coach cue `high_bpm` (92% disso).
        // Sem profile/maxBpm, o cue é skip silenciosamente — não estimamos
        // por 220-age aqui pra evitar avisos errados em quem nunca testou.
        _userMaxBpm = profile?.maxBpm;
      } catch (_) {/* mantém defaults */}
    }
    // Reset acumuladores de BPM por km e inicia stream nativo. Idempotente —
    // se a service estiver active de uma run anterior, é no-op.
    _kmBpmSamples.clear();
    _lastBpmAtMs = null;
    _bpmStaleLogged = false;
    _bpmSub?.cancel(); _stepsSub?.cancel(); _spo2Sub?.cancel();
    _bpmSub = workoutRealtimeService.bpmStream.listen(
      (v) => add(_BpmTick(v)),
    );
    // TF 75 Fase 1: steps cumulative buffer pro gate idle.
    _stepsSub?.cancel(); _spo2Sub?.cancel();
    _stepsBuf.clear();
    _stepsSub = workoutRealtimeService.stepsStream.listen((total) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      _stepsBuf.add((ts: nowMs, total: total));
      // Pruna entries fora da janela de 60s.
      _stepsBuf.removeWhere((e) => nowMs - e.ts > _stepsIdleWindowMs * 2);
    });
    // TF 75 Fase 12: SpO2 sub — dispara event interno que atualiza state.
    _spo2Sub?.cancel();
    _spo2Sub = workoutRealtimeService.spo2Stream.listen((pct) {
      if (!isClosed) add(_Spo2Tick(pct));
    });
    unawaited(workoutRealtimeService.start());
    // TF 75 Fase 0 (CRÍTICO): mantém AVAudioSession ativa via silent audio
    // loop. Sem isso, Dart engine suspende em background entre cues do
    // coach → cues param 5min com tela bloqueada (regressão TF 74).
    unawaited(AudioSessionKeepalive.instance.startKeepalive());

    // Agenda fallback: em 1s, se realtime ainda não emitiu, começa polling.
    _bpmFallbackPollTimer?.cancel();
    _bpmFallbackPollTimer = Timer(
      const Duration(seconds: _bpmFallbackWarmupSec),
      _maybeStartBpmFallbackPolling,
    );
    // Sync periódico em paralelo: empurra TODOS os tipos (bpm/hrv/steps/...)
    // pro server durante a corrida. Cancela em pause/abandon/complete.
    _runHealthSyncTimer?.cancel();
    _runHealthSyncTimer = Timer.periodic(
      const Duration(seconds: _runHealthSyncIntervalSec),
      (_) => unawaited(healthSyncService.syncSince()),
    );

    // Lifecycle observer pra detectar app→background. Sem isso, GPS e bpmSub
    // continuam ativos (LocationSettings já garante), mas timers UI ficariam
    // ligados desnecessariamente — pausamos só esses na transição.
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    // ignore: avoid_print
    print('coach.alert_prefs.resolved=$_alertPrefs');
    _lastCueAt.clear();
    _planSessionId = event.planSessionId;
    _segments = const [];
    _currentSegmentIdx = -1;
    _plannedDistanceM = null;
    _goalReachedFired = false;
    // Premium: usa LiveRunCoachSession (Gemini Live). Freemium: TTS local
    // de telemetria a cada km. Default true mantém retro-compat se um
    // caller antigo não passar o flag.
    _isPremium = event.isPremium ?? true;
    // TF 77 F3: origem do start. Watch=true ⇒ LA não inicia.
    _startSource = event.startSource;
    // ignore: avoid_print
    print('run.mode.resolved isPremium=$_isPremium type=${event.type}');

    // Resolve a sessão planejada já no start. Saudação inicial e cues
    // segment_* leem daqui — sem isso, primeiro segment_start poderia
    // demorar pra disparar enquanto plano carrega.
    if (event.planSessionId != null) {
      unawaited(_loadPlanSession(event.planSessionId!));
    }

    emit(
      state.copyWith(
        status: RunStatus.starting,
        runType: event.type,
        targetPace: event.targetPace,
        targetDistance: event.targetDistance,
      ),
    );
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Ative o GPS do dispositivo para iniciar a corrida.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Permita o acesso a localizacao para iniciar a corrida.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'A permissao de localizacao foi bloqueada. Libere nas configuracoes do aparelho.',
        );
      }

      String runId;
      try {
        final run = await _remote.createRun(
          type: event.type,
          targetPace: event.targetPace,
          targetDistance: event.targetDistance,
          planSessionId: event.planSessionId,
        );
        runId = run.id;
      } catch (_) {
        // Modo local-first: se API falhar no start, a corrida ainda começa com GPS.
        runId = _buildLocalRunId();
      }

      emit(
        state.copyWith(
          status: RunStatus.active,
          runId: runId,
          points: [],
          distanceM: 0,
          elapsedS: 0,
          coachLiveMessage: null,
          coachAudioBase64: '',
          coachAudioMimeType: '',
          error: null,
        ),
      );
      // Empurra status=active pro Watch IMEDIATAMENTE em vez de esperar
      // o primeiro _onTimerTick (1Hz). Sem isso o Watch fica preso em
      // "INICIANDO…" no BriefingScreen por até 1s — e às vezes mais
      // (sim do Watch tem reachability intermitente). Idempotente quando
      // Watch não pareado.
      _pushStatusToWatch('active');

      _lastCoachKm = 0;
      _lastKmStartElapsedS = 0;
      _pendingRotationTrigger = null;
      _gpsDriftWindow.clear();
      // Wall-clock anchor pra elapsedS (vide _onTimerTick).
      _startedAtMs = DateTime.now().millisecondsSinceEpoch;
      _pausedTotalMs = 0;
      _pauseStartMs = null;
      if (_isPremium) {
        // TF 71 Fase -2: se uma sessão Live anterior ainda está aberta,
        // user iniciou nova run sem stop. Sem dispose explícito a sessão
        // antiga seguia reconectando indefinidamente (TF 70 deu resiliência
        // demais), consumindo tokens da run que terminou. Fecha e recria.
        if (_coachSession.isOpen) {
          unawaited(_coachSession.close());
          _coachTranscriptSub?.cancel();
          _coachTranscriptSub = null;
          _coachSession = LiveRunCoachSession(contextManager: _coachCtx);
        }
        // Premium: contexto + Live session + saudação (mesmo fluxo de sempre).
        _coachCtx.init(runId);
        _coachSession.setMetricsProvider(_buildMetricsSnapshot);
        // Abre a sessão Live e saúda AGORA — ao iniciar, quando a tela passa a
        // exibir o mapa (corrida ativa). Suprime cues por 12s pra a saudação
        // falar sozinha. A transcrição alimenta o banner; o áudio toca na sessão.
        if (!_coachSession.isOpen) {
          _suppressCuesUntilMs = DateTime.now().millisecondsSinceEpoch + 12000;
          _coachTranscriptSub?.cancel();
          _coachTranscriptSub = _coachSession.transcripts.listen((t) {
            if (!isClosed) add(_CoachChunk(CoachCue(text: t)));
          });
          final startType = event.type;
          final startRunId = runId;
          unawaited(() async {
            // Refetch de clima ANTES de abrir a Live session — snapshot
            // capturado na home pode ter horas de idade. Best-effort: 3s
            // timeout pra não atrasar o start visível. Briefing do coach
            // (build-run-coach-instruction) só usa clima se chegar fresh.
            if (locationWeatherController.isStale) {
              try {
                await locationWeatherController.refresh().timeout(
                      const Duration(seconds: 3),
                      onTimeout: () {},
                    );
              } catch (_) {/* mantém snapshot anterior */}
            }
            final ok = await _coachSession.open(
              planSessionId: _planSessionId,
              runId: startRunId,
            );
            if (ok && !isClosed) {
              _coachSession.markTrigger('start');
              _coachSession.sendTelemetry(_telemetryText('start', runType: startType));
              // Inicializa os trackers de check_in (500m / 4min) com a
              // saudação. Sem isso, os gates `_lastCoachSpeechAtMs > 0`
              // nos triggers de check_in nunca passavam em runs premium
              // (só freemium chamava _requestCoachCue no start) — coach
              // ficava mudo após a primeira fala.
              _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
              _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
              _lastCoachSpeechDistanceM = 0;
            }
          }());
        }
      } else {
        // Freemium: pula a sessão Live e fala localmente. Banner mostra a
        // saudação; TTS on-device toca em paralelo (best-effort, falha
        // silenciosa se engine indisponível).
        final greeting = TelemetryTts.formatStart(event.type);
        emit(state.copyWith(coachLiveMessage: greeting));
        unawaited(TelemetryTts.instance.speak(greeting));
        _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
        _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
        _lastCoachSpeechDistanceM = 0;
      }

      // Timer de tempo decorrido — cancela QUALQUER timer anterior. Sem
      // isso, double-StartRun (ex: user clica TENTAR NOVAMENTE no Watch
      // depois da corrida ter iniciado pelo telefone) cria 2 timers
      // concorrentes que fazem elapsedS subir 2/sec — relógio "corre
      // mais rápido".
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(_TimerTick()),
      );

      // Telemetria sincronizada 30s — snapshot {bpm, pace, distância} no
      // mesmo instante. Cancelado em pause/complete/abandon (vide handlers).
      _telemetryTickTimer?.cancel();
      _telemetryTickTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => add(_TelemetryTick()),
      );

      // Motivação: dispara cue a cada 5min se não houver outro cue ativo.
      // Respeita _alertPrefs['motivation'] (no-op se false).
      _startMotivationTimer();

      // Safety pra rotação Live: garante que a sessão não estoure o cap
      // do Gemini (~10min) mesmo em runs lentas ou sem transições de
      // segmento. Roda a cada 30s e tenta rotacionar se shouldRotateNow.
      _startCoachRotationSafetyTimer();

      // Stall check: 30s após START, se distância < 5m, pede ao coach um
      // disclaimer gentil ("tudo bem? começa quando puder").
      // One-shot — reset por StartRun (não dispara em resume).
      //
      // TF 69: removida exigência de `state.points.isNotEmpty`. Antes só
      // disparava se houve fix GPS, deixando cenário indoor (Eduardo no
      // teste BPM parado) sem cue mesmo após 3min de imobilidade. Coach
      // tem template `no_movement` que cobre "GPS travado?" sem precisar
      // de fix prévio.
      _stallCueFired = false;
      _stallCheckTimer?.cancel();
      _stallCheckTimer = Timer(const Duration(seconds: 30), () {
        if (isClosed || _stallCueFired) return;
        if (state.status != RunStatus.active) return;
        if (state.distanceM >= 5.0) return; // moveu, OK
        _stallCueFired = true;
        unawaited(_requestCoachCue(
          event: 'no_movement',
          distanceM: state.distanceM,
          elapsedS: state.elapsedS,
          currentPaceMinKm: state.currentPaceMinKm,
        ));
        _lastCueAt['no_movement'] = DateTime.now().millisecondsSinceEpoch;
        // Pausa a run e pede o dialog de continuar/encerrar.
        add(_NoMovementDetected());
      });

      // GPS: web browser não emite stream confiável (depende de
      // movimento real >5m, e WiFi-based geolocation tem accuracy 1000m+
      // que o filter rejeita). Em web usamos polling getCurrentPosition
      // a cada 3s — sempre entrega um ponto, mesmo parado. Native
      // mantém stream com distanceFilter (mais eficiente, sem bateria
      // extra).
      if (kIsWeb) {
        // Settings web: medium + timeLimit 20s. 8s era curto demais —
        // browser WiFi-triangulation pode levar 10s+ no cold-start
        // (especialmente em corp net/VPN). Polling continua 5s mas
        // cada call tem 20s pra responder.
        const webSettings = LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        );
        // Primeiro ponto: tenta getCurrentPosition; se timeout, cai no
        // cache do browser via getLastKnownPosition.
        () async {
          try {
            final pos = await Geolocator.getCurrentPosition(locationSettings: webSettings);
            // ignore: avoid_print
            print('gps.web.first_fix accuracy=${pos.accuracy.toStringAsFixed(0)}m '
                'lat=${pos.latitude.toStringAsFixed(4)} lng=${pos.longitude.toStringAsFixed(4)}');
            if (!isClosed) add(_GpsUpdate(pos));
          } catch (err) {
            // ignore: avoid_print
            print('gps.web.first_fix_failed: $err — tentando cache lastKnown');
            try {
              final cached = await Geolocator.getLastKnownPosition();
              if (cached != null && !isClosed) {
                // ignore: avoid_print
                print('gps.web.first_fix.cache_hit accuracy=${cached.accuracy.toStringAsFixed(0)}m');
                add(_GpsUpdate(cached));
              } else {
                // ignore: avoid_print
                print('gps.web.first_fix.cache_miss — polling vai tentar');
              }
            } catch (e2) {
              // ignore: avoid_print
              print('gps.web.cache_failed: $e2');
            }
          }
        }();
        // Polling 5s — antes era 3s + timeLimit 8s, conflitava (poll
        // dispara antes do timeout). Agora 5s + timeLimit 20s.
        int consecutiveFails = 0;
        _gpsPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          Geolocator.getCurrentPosition(locationSettings: webSettings)
              .then((pos) {
            consecutiveFails = 0;
            // ignore: avoid_print
            print('gps.web.poll.success accuracy=${pos.accuracy.toStringAsFixed(0)}m');
            if (!isClosed) add(_GpsUpdate(pos));
          }).catchError((err) {
            consecutiveFails++;
            // ignore: avoid_print
            print('gps.web.poll.failed count=$consecutiveFails: $err');
            // Após 3 falhas seguidas (~15s sem fix) loga warning bem
            // visível. Recovery UI (avisar user, repedir permissão) é
            // follow-up; chip de GPS na ActiveRunPage já oferece retry
            // manual via tap (GpsPermissionModal).
            if (consecutiveFails == 3) {
              // ignore: avoid_print
              print('gps.web.poll.DEGRADED: 3 falhas seguidas — usuário precisa rechecar permissão');
            }
          });
        });
      } else if (mockGpsService.enabled) {
        // Modo mock (debug-only): simula posições com pace configurável
        // pra exercitar o fluxo de corrida em simulator ou sem sair de
        // casa. Mock só liga em kDebugMode (guard interno do service).
        Logger.warn('run.mock_gps.enabled', context: {
          'paceMinKm': '${mockGpsService.paceMinKm}',
        });
        _gpsSub = mockGpsService
            .stream()
            .listen((pos) => add(_GpsUpdate(pos)));
      } else {
        _gpsSub = Geolocator.getPositionStream(
          locationSettings: _runLocationSettings(),
        ).listen((pos) => add(_GpsUpdate(pos)));

        Geolocator.getCurrentPosition(
          locationSettings: _runLocationSettings(),
        ).then((pos) {
          if (!isClosed) add(_GpsUpdate(pos));
        }).catchError((_) {});
      }

      // Flush periódico
      _flushTimer = Timer.periodic(
        const Duration(seconds: _flushIntervalS),
        (_) => _flush(),
      );
    } catch (e) {
      emit(state.copyWith(status: RunStatus.error, error: e.toString()));
    }
  }

  /// Snapshot sincronizado {bpm, pace, distância} → telemetryTimeline.
  /// Fix TF 59: BPM e GPS chegam por streams diferentes com latência
  /// variável; este tick é o único ponto onde os 3 sinais são amarrados ao
  /// MESMO instante temporal. Usado pelo coach (cue 500m lê últimos N
  /// ticks) e pelo relatório/revisão semanal pra ver a curva real.
  void _onTelemetryTick(_TelemetryTick event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;
    final startedAt = _startedAtMs;
    if (startedAt == null) return;
    final tMs = DateTime.now().millisecondsSinceEpoch - startedAt - _pausedTotalMs;
    final paceSec = state.currentPaceMinKm != null
        ? (state.currentPaceMinKm! * 60).round()
        : null;
    final point = TelemetryPoint(
      tMs: tMs,
      distM: state.distanceM,
      bpm: state.currentBpm,
      paceSec: paceSec,
    );
    // Cap defensivo de 1500 ticks (12.5h a 30s/tick). Drop oldest se passar.
    final updated = state.telemetryTimeline.length >= 1500
        ? [...state.telemetryTimeline.skip(1), point]
        : [...state.telemetryTimeline, point];
    emit(state.copyWith(telemetryTimeline: updated));
  }

  void _onTimerTick(_TimerTick event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;
    // Staleness em 3 estados:
    //   - fresh: último sample em até _bpmStaleSecs (15s)
    //   - stale: 15-45s — UI mostra último valor com aviso "?" e dispara
    //     1 retry do fallback poll
    //   - lost:  >45s — UI mostra "—", fallback poll periódico arrancado e
    //     iOS query reiniciada via workoutRealtimeService.restart()
    //
    // Wall-clock truth: derivamos elapsedS de (now - startedAt - pausedTotal)
    // em vez de contador incremental. iOS suspende o Dart isolate em bg e o
    // Timer.periodic perde/atrasa ticks; com background mode `location` o
    // isolate ainda roda ALGUNS ticks → contador incremental ficava entre
    // congelado e dobrado. Agora o tick só dispara re-render UI; o valor
    // real vem da diferença wall-clock e o relatório fica fiel ao tempo
    // real (corrida de 21min reais não vira 36min).
    final startedAt = _startedAtMs;
    final newElapsed = startedAt == null
        ? state.elapsedS + 1
        : ((DateTime.now().millisecondsSinceEpoch - startedAt - _pausedTotalMs) / 1000).round();
    final target = _resolveBpmStaleness();
    if (target != state.bpmStaleness) {
      _onBpmStalenessTransition(target);
      emit(state.copyWith(elapsedS: newElapsed, bpmStaleness: target));
    } else {
      emit(state.copyWith(elapsedS: newElapsed));
    }
    // Live Activity ALWAYS — não condiciona em background. Apple exige que
    // `Activity.request()` seja chamado em FOREGROUND (lança em bg) — antes
    // só chamávamos quando _appInBackground=true, ou seja, JÁ depois do
    // app pra bg → request falhava silenciosamente e caía pra notif
    // pequena. Agora chamamos a cada tick (1Hz) em ambos os estados;
    // updates subsequentes (após o start) funcionam em bg sem problemas.
    unawaited(runBgNotificationService.update(
      distanceM: state.distanceM,
      elapsedS: newElapsed,
      paceMinKm: state.currentPaceMinKm,
      sessionType: state.runType,
      bpm: state.bpmSourceActive ? state.currentBpm : null, startSource: _startSource,
    ));
    // Push state pro Watch — 1Hz. updateApplicationContext dedup automático
    // (entrega só o último valor se Watch tava offline). Idempotente quando
    // Watch app não instalado (plugin skips com log).
    unawaited(workoutRealtimeService.pushRunState({
      'type': 'run_state',
      'status': 'active',
      'elapsedS': newElapsed,
      'distanceM': state.distanceM,
      // Fallbacks pra 0/Free Run — o pushRunState sanitiza nulls defensivamente,
      // mas explicitar aqui deixa as intenções claras (paceMinKm fica null
      // antes do primeiro km computar).
      'paceMinKm': state.currentPaceMinKm ?? 0,
      'bpm': state.currentBpm ?? 0,
      'caloriesKcal': _approxCalories(state.distanceM),
      'elevationM': _approxElevationGain(state.splits),
      'runType': state.runType ?? 'Free Run',
      // Splits compactados pra o Watch renderizar a pág 3 (Splits). Mantém
      // só os campos essenciais — payload ≤ ~64KB do applicationContext.
      'splits': state.splits
          .map((s) => {
                'km': s.kmIndex + 1,
                'durationS': s.durationS,
                'pace': s.avgPaceMinKm,
                'bpm': s.avgBpm ?? 0,
                'elev': s.elevationGain ?? 0,
              })
          .toList(),
    }));
  }

  /// Empurra snapshot mínimo de transição de status pro Watch. Usado em
  /// pause/resume/abandon/complete — fora do tick periódico, garante que o
  /// Watch transiciona de UI imediatamente em vez de esperar +1s.
  void _pushStatusToWatch(String status) {
    unawaited(workoutRealtimeService.pushRunState({
      'type': 'run_state',
      'status': status,
      'elapsedS': state.elapsedS,
      'distanceM': state.distanceM,
      // Mesmo defesa do _onTimerTick — paceMinKm é null antes do primeiro km.
      'paceMinKm': state.currentPaceMinKm ?? 0,
      'bpm': state.currentBpm ?? 0,
      'caloriesKcal': _approxCalories(state.distanceM),
      'elevationM': _approxElevationGain(state.splits),
      'runType': state.runType ?? 'Free Run',
    }));
  }

  /// Aproximação simples de calorias pelo distância (60 kcal/km, ajustar
  /// futuramente com BPM + peso). Usado só pra exibir no Watch — não vai
  /// pro server (a corrida finalizada usa cálculo correto server-side).
  double _approxCalories(double distanceM) => (distanceM / 1000.0) * 60.0;

  /// Soma elevationGain dos splits fechados — fonte: campos do KmSplit.
  double _approxElevationGain(List<KmSplit> splits) {
    var total = 0.0;
    for (final s in splits) {
      total += s.elevationGain ?? 0;
    }
    return total;
  }

  void _onCoachChunk(_CoachChunk event, Emitter<RunState> emit) {
    // O texto vem da transcrição da fala da sessão Live (texto == voz). O
    // áudio toca dentro da própria sessão (LiveRunCoachSession), por isso
    // NÃO passamos audioBase64 — o player da tela não duplica a fala.
    emit(
      state.copyWith(
        coachLiveMessage: event.cue.text,
        coachAudioBase64: '',
        coachAudioMimeType: '',
      ),
    );
    // Saudação chega como _CoachChunk mas não passa por _requestCoachCue,
    // então _lastCoachSpeechAtMs ficava em 0 — bloqueando o check-in de
    // 500m e o timer de 4min que exigem > 0.
    if (_lastCoachSpeechAtMs == 0) {
      _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
      _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
      _lastCoachSpeechDistanceM = state.distanceM;
    }
  }

  void _onGpsUpdate(_GpsUpdate event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;

    final pos = event.pos;

    // Antes: descartávamos pontos com accuracy > 10km no web. Resultado:
    // toda fix por WiFi-triangulation (5-20km de raio comum em desktop)
    // sumia silenciosamente, chip ficava AGUARDANDO eternamente.
    // Agora no web aceitamos qualquer accuracy pra display (chip acende,
    // mapa centraliza), mas só contamos distância se accuracy ≤ 5km
    // (vide _accuracyThreshold mais abaixo). Log das descartadas pra
    // saber se algo ainda some.
    if (kIsWeb) {
      // ignore: avoid_print
      print('gps.web.point.accept accuracy=${pos.accuracy.toStringAsFixed(0)}m');
    } else if (pos.accuracy > _displayAccuracyThreshold) {
      // ignore: avoid_print
      print('gps.point.dropped accuracy=${pos.accuracy.toStringAsFixed(0)}m threshold=${_displayAccuracyThreshold.toStringAsFixed(0)}m');
      return;
    }

    // pos.altitude: geolocator devolve 0 quando o device não disponibiliza
    // (web sem barômetro, fallback de IP). Filtramos 0 pra não inflar split
    // com elevação fake — splits ficam com elevationGain null nesse caso.
    final altitude = pos.altitude != 0 ? pos.altitude : null;
    final newPoint = GpsPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      ts: pos.timestamp.millisecondsSinceEpoch,
      accuracy: pos.accuracy,
      altitude: altitude,
      pace: pos.speed > 0 ? (1000 / pos.speed) / 60 : null, // m/s → min/km
      // BPM live anexado a cada GPS point pra `computeKmSplits` poder
      // computar `avgBpm` por km. Sem isso, splits saíam com avgBpm=null
      // pra TODA corrida nova (mesmo com Apple Watch conectado), e o
      // gráfico de zonas no detalhe da corrida + agregação de zonas no
      // histórico ficavam vazios. `state.currentBpm` pode ser null se
      // realtime ainda não emitiu, fallback poll vai preencher splits
      // subsequentes.
      bpm: state.currentBpm,
    );

    // Calcula distância incremental
    double addedDistance = 0;
    if (state.points.isNotEmpty) {
      final last = state.points.last;
      final accurateEnough =
          pos.accuracy <= _accuracyThreshold &&
          last.accuracy <= _accuracyThreshold;
      if (accurateEnough) {
        final rawDistance = Geolocator.distanceBetween(
          last.lat,
          last.lng,
          pos.latitude,
          pos.longitude,
        );
        // TF 70: filtro anti-drift GPS indoor. Sem isso, GPS indoor faz
        // pontos pingarem entre torres e acumulamos distância fake mesmo
        // user parado. Coach disparou cue "500m completados" no teste
        // TF 69 do Eduardo sem ele sair do lugar.
        //
        // Gate triplo:
        //   1) pos.speed >= 0.5 m/s (1.8 km/h, mais lento que caminhar
        //      muito devagar — implies user parado ou ruído)
        //   2) deltaTms >= 2s (impede que samples muito próximos somem)
        //   3) implied speed (delta/dt) <= 8 m/s (28.8 km/h, mais rápido
        //      que sprint humano — implies teleporte de drift)
        //
        // pos.speed=0 vem do iOS quando navegação não tem confiança no
        // movimento. Aceitamos quando pos.speed > minMovement.
        final dtMs = pos.timestamp.millisecondsSinceEpoch - last.ts;
        final dtSec = dtMs / 1000;
        final impliedSpeed = dtSec > 0 ? rawDistance / dtSec : 0;
        const minMovementMps = 0.5; // 1.8 km/h
        const maxImpliedSpeed = 8.0; // 28.8 km/h
        // speed <= 0 = desconhecido (mock/emulador ou GPS sem lock) — omite
        // o gate de velocidade e confia só em impliedSpeed.
        // minDeltaSec removido: impliedSpeed <= 8 m/s já rejeita teleportes
        // independente do dt; o gate de 2s bloqueava o mock GPS (1Hz) e
        // corridas rápidas com distanceFilter=5m.
        final speedOk = pos.speed <= 0 || pos.speed >= minMovementMps;
        final isRealMovement = speedOk && impliedSpeed <= maxImpliedSpeed;
        if (isRealMovement) {
          addedDistance = rawDistance;
        } else {
          // ignore: avoid_print
          print('gps.drift.rejected raw=${rawDistance.toStringAsFixed(1)}m '
              'speed=${pos.speed.toStringAsFixed(2)} '
              'dt=${dtSec.toStringAsFixed(1)}s '
              'implied=${impliedSpeed.toStringAsFixed(2)}m/s');
        }
      }
    }

    // TF 75 Fase 1: gate por passos do Watch — fonte mais confiável que
    // pace. Se Watch reporta 0 passos em 60s, qualquer delta GPS é drift,
    // independente do pace aparente. Watch ausente = retorna null → cai
    // no gate cumulativo abaixo.
    final stepIdle = _isStepIdle60s();
    if (stepIdle == true && addedDistance > 0) {
      // ignore: avoid_print
      print('gps.drift.rejected_step_idle raw=${addedDistance.toStringAsFixed(1)}m');
      addedDistance = 0;
    }

    // TF 71 Fase -3: gate cumulativo de 60s. Per-point gate (TF 70) deixou
    // passar drift em janela larga — Eduardo viu "500m concluído" sem sair
    // do lugar. Aqui, se a soma dos pontos aceitos nos últimos 60s gera
    // pace agregado > 12 min/km (caminhada arrastada), descartamos o último
    // delta — quase certamente é GPS oscilando.
    if (addedDistance > 0) {
      final nowMs = pos.timestamp.millisecondsSinceEpoch;
      _gpsDriftWindow.removeWhere((e) => nowMs - e.ts > _driftWindowMs);
      _gpsDriftWindow.add((ts: nowMs, dist: addedDistance));
      if (_gpsDriftWindow.length >= 3) {
        final firstTs = _gpsDriftWindow.first.ts;
        final spanS = (nowMs - firstTs) / 1000.0;
        if (spanS >= 30) {
          final sumDist = _gpsDriftWindow.fold<double>(0, (a, b) => a + b.dist);
          // pace min/km = spanMin / km; spanMin = spanS/60; km = sumDist/1000
          final paceMinKm = (spanS / 60.0) / (sumDist / 1000.0);
          if (paceMinKm > _driftMaxPaceMinKm) {
            // ignore: avoid_print
            print('gps.drift.cumulative_rejected '
                'sumDist=${sumDist.toStringAsFixed(1)}m '
                'spanS=${spanS.toStringAsFixed(1)} '
                'pace=${paceMinKm.toStringAsFixed(1)}min/km');
            _gpsDriftWindow.removeLast();
            addedDistance = 0;
          }
        }
      }
    }

    // Só adiciona pontos aceitos pelo filtro de drift. computeKmSplits usa
    // haversine em todos os pontos sem filtrar — se drift points entrassem
    // aqui, cumDist divergia de state.distanceM e os kmIndex ficavam errados
    // (ex: KM07/KM08 com distância real de 4km e speeds de 34 km/h).
    // Primeiro ponto sempre entra (âncora inicial sem ponto anterior).
    final newPoints = (state.points.isEmpty || addedDistance > 0)
        ? [...state.points, newPoint]
        : state.points;
    final newDistance = state.distanceM + addedDistance;

    // Pace instantâneo pela distância/tempo real dos últimos ~30m (robusto
    // contra drift de GPS parado, que com pos.speed cru gerava pace absurdo
    // tipo 235 min/km). null quando parado/ruído → UI mostra "--:--" e os
    // cues de pace (pace_alert/segment_pace_off) não disparam à toa.
    final smoothedPace = rollingPaceMinKm(newPoints);

    final kmReached = (newDistance / 1000).floor();
    final crossedKmBoundary = kmReached > _lastCoachKm && kmReached > 0;

    // Quando cruza fronteira de km, recomputa splits do zero (cheap pra
    // ~10km de corrida, ~10x por run). Mantém todos os splits anteriores
    // em ordem, agora com os campos completos (pace agregado, duração,
    // BPM médio) que a UI dos cards precisa.
    final updatedSplits = crossedKmBoundary
        ? computeKmSplits(newPoints)
        : state.splits;

    emit(
      state.copyWith(
        points: newPoints,
        distanceM: newDistance,
        currentPaceMinKm: smoothedPace,
        splits: updatedSplits,
      ),
    );

    // TF 75 Fase 4: km_reached PRIMEIRO (antes do check_in 500m). Quando
    // user cruza km exato, evita 2 cues sobrepostos — km_reached atualiza
    // `_lastCoachSpeechDistanceM = state.distanceM`, fazendo o gate do
    // check_in ver delta=0 e skip natural na mesma iteração.
    if (crossedKmBoundary) {
      _lastCoachKm = kmReached;
      // Live Activity sempre — request precisa ser foreground (ver comentário
      // em _onTimerTick). Updates sucessivos funcionam em qualquer estado.
      unawaited(runBgNotificationService.update(
        distanceM: newDistance,
        elapsedS: state.elapsedS,
        paceMinKm: smoothedPace,
        sessionType: state.runType,
        bpm: state.bpmSourceActive ? state.currentBpm : null, startSource: _startSource,
      ));
      // Tempo do km que acabou de cruzar (não acumulado). Coach reporta
      // "1 km em X min" + server estima calorias do km (MET × peso × tempo).
      final kmDurationS = state.elapsedS - _lastKmStartElapsedS;
      _lastKmStartElapsedS = state.elapsedS;
      // BPM médio dos samples desse km (acumulados em _onBpmTick).
      // Vazio quando sem wearable conectado — kmAvgBpm fica null e o coach
      // cue omite a linha "frequência cardíaca X".
      int? kmAvgBpm;
      if (_kmBpmSamples.isNotEmpty) {
        kmAvgBpm = (_kmBpmSamples.reduce((a, b) => a + b) / _kmBpmSamples.length).round();
      }
      _kmBpmSamples.clear();
      // Cue 1: km_reached (info imediato sobre o km que acabou).
      // _lastCoachKm já dedup (1x por km), sem cooldown adicional.
      if (_alertPrefs['kmAlert'] == true) {
        // Alvo: segment.targetPace > session.targetPace > null. Sem alvo no
        // payload, o LLM não conseguia entregar a fala "seu pace foi X, alvo
        // Y" que o user pediu — ficava com narração genérica.
        final kmNow = newDistance / 1000;
        PlanSegment? segHere;
        for (final s in _segments) {
          if (kmNow >= s.kmStart && kmNow < s.kmEnd) {
            segHere = s;
            break;
          }
        }
        final kmTarget = _parsePaceMinKm(segHere?.targetPace) ??
            _parsePaceMinKm(state.targetPace);
        // UMA fala por km: pace + tempo do km + ganho de elevação, e o coach
        // compara com a fase do roteiro (contexto vem no systemInstruction).
        unawaited(_requestCoachCue(
          event: 'km_reached',
          kmReached: kmReached,
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          targetPaceMinKm: kmTarget,
          kmDurationS: kmDurationS,
          kmAvgBpm: kmAvgBpm,
          elevationGainM:
              updatedSplits.isNotEmpty ? updatedSplits.last.elevationGain : null,
        ));
        _lastCueAt['km_reached'] = DateTime.now().millisecondsSinceEpoch;
        _maybeRotateLiveSession(trigger: 'km_reached');
      }
      // km_split removido em rev 51: era duplicata do km_reached (ambos
      // disparavam ao cruzar km, gerando 2 calls LLM com info subset).
      // O km_reached já carrega pace + target + duração + BPM — server
      // sintetiza tudo no cue.
    }

    // Goal reached: a sessão planejada tem distanceKm > 0 e o user acabou
    // de cruzar esse alvo. Cue avisa "sua sessão termina aqui — se quiser
    // continuar, eu sigo" sem auto-completar a run. One-shot.
    if (!_goalReachedFired &&
        _plannedDistanceM != null &&
        newDistance >= _plannedDistanceM!) {
      _goalReachedFired = true;
      unawaited(_requestCoachCue(
        event: 'goal_reached',
        distanceM: newDistance,
        elapsedS: state.elapsedS,
        currentPaceMinKm: smoothedPace,
      ));
      _lastCueAt['goal_reached'] = DateTime.now().millisecondsSinceEpoch;
    }

    // Check-in canônico por distância: a cada 500m sem o coach falar,
    // dispara um cue de presença. Junto com o check_in por tempo (4min,
    // vide _startMotivationTimer), garante que o coach sempre acompanha
    // o user mesmo quando tudo está conforme o plano.
    //
    // TF 72 fix: gate por pace real. Se user tá parado (smoothedPace null
    // ou > 12 min/km — caminhada arrastada), o `motivation timer` cobre
    // (~4min idle). Sem esse gate, drift GPS sub-threshold somava 500m
    // parado e disparava cue "check_in" com pace bizarro.
    //
    // TF 75 Fase 4: roda DEPOIS de km_reached. Se km_reached acabou de
    // disparar nesta mesma iteração, ele zerou _lastCoachSpeechDistanceM
    // (via _requestCoachCue → state.distanceM == newDistance), e o
    // delta abaixo vira 0 → skip natural.
    final smoothedPaceForGate = smoothedPace;
    final isUserMoving = smoothedPaceForGate != null && smoothedPaceForGate < 12.0;
    if (state.status == RunStatus.active &&
        _lastCoachSpeechAtMs > 0 &&
        isUserMoving &&
        newDistance - _lastCoachSpeechDistanceM >= _checkInDistanceM) {
      final paceLast500m = rollingPaceMinKm(
        newPoints,
        windowMeters: 500,
        maxWindowMs: 600000,
      );
      final kmRemaining = _plannedDistanceM != null
          ? max(0.0, (_plannedDistanceM! - newDistance) / 1000.0)
          : null;
      unawaited(_requestCoachCue(
        event: 'check_in',
        distanceM: newDistance,
        elapsedS: state.elapsedS,
        currentPaceMinKm: smoothedPace,
        paceLast500m: paceLast500m,
        kmRemaining: kmRemaining,
      ));
    }

    // Detecção de transição de segment. Roda só quando há plano com
    // segments — Free Run mantém o pace_alert legado abaixo. A regra:
    // - segment_start quando _currentSegmentIdx muda (entrou em segment novo)
    // - segment_pace_off com cooldown 60s (substitui pace_alert quando ativo)
    // - segment_end quando ultrapassa kmEnd do último segment
    final hasSegments = _segments.isNotEmpty;
    PlanSegment? activeSegment;
    int? activeSegmentIdx;
    if (hasSegments) {
      final kmNow = newDistance / 1000;
      // Procura segment cujo [kmStart, kmEnd) contém o km atual.
      for (var i = 0; i < _segments.length; i++) {
        final s = _segments[i];
        if (kmNow >= s.kmStart && kmNow < s.kmEnd) {
          activeSegmentIdx = i;
          activeSegment = s;
          break;
        }
      }

      // Detecta transição: novo segment_start.
      if (activeSegmentIdx != null && activeSegmentIdx != _currentSegmentIdx) {
        final previousIdx = _currentSegmentIdx;
        _currentSegmentIdx = activeSegmentIdx;
        _requestCoachCue(
          event: 'segment_start',
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          targetPaceMinKm: _parsePaceMinKm(activeSegment?.targetPace),
          currentSegmentIndex: activeSegmentIdx,
        );
        _lastCueAt['segment_start'] = DateTime.now().millisecondsSinceEpoch;
        _maybeRotateLiveSession(trigger: 'segment_start');
        // ignore: avoid_print
        print('coach.segment.transition prev=$previousIdx now=$activeSegmentIdx phase=${activeSegment?.phase}');
      }

      // Detecta término do último segment: passou de kmEnd final.
      // _currentSegmentIdx fica no último; dispara só uma vez por run.
      if (activeSegmentIdx == null && _currentSegmentIdx >= 0 &&
          _cooldownOk('segment_end', seconds: 999999)) {
        _requestCoachCue(
          event: 'segment_end',
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          currentSegmentIndex: _currentSegmentIdx,
        );
        _lastCueAt['segment_end'] = DateTime.now().millisecondsSinceEpoch;
        _maybeRotateLiveSession(trigger: 'segment_end');
      }

      // segment_pace_off: substitui pace_alert genérico quando segment
    }

    // Pace alert unificado (rev 51): antes existiam 2 eventos —
    // `pace_alert` (alvo da sessão) e `segment_pace_off` (alvo do segmento
    // ativo). Conteúdo do cue era idêntico, só o alvo mudava — geravam
    // calls LLM duplicadas com cooldowns independentes.
    //
    // Agora: 1 evento `pace_alert`. Target = segment.targetPace quando há
    // segment ativo COM alvo; caso contrário cai pra session.targetPace.
    // Server recebe `currentSegmentIndex` quando aplicável pra contextualizar.
    if (_alertPrefs['paceOutOfRange'] == true &&
        smoothedPace != null &&
        state.status == RunStatus.active &&
        _cooldownOk('pace_alert', seconds: 60)) {
      final targetPaceStr = activeSegment?.targetPace ?? state.targetPace;
      final targetPace = _parsePaceMinKm(targetPaceStr);
      if (targetPace != null) {
        final deviation = (smoothedPace - targetPace).abs() / targetPace;
        if (deviation >= 0.10) {
          _requestCoachCue(
            event: 'pace_alert',
            currentPaceMinKm: smoothedPace,
            targetPaceMinKm: targetPace,
            distanceM: newDistance,
            elapsedS: state.elapsedS,
            currentSegmentIndex:
                activeSegment?.targetPace != null ? activeSegmentIdx : null,
          );
          _lastCueAt['pace_alert'] = DateTime.now().millisecondsSinceEpoch;
        }
      }
    }
    // BPM live + cue high_bpm agora vivem em _onBpmTick — alimentado pelo
    // workoutRealtimeService (HKWorkoutSession iOS / HealthServicesClient
    // Android). Sample chega a ~1Hz quando há wearable pareado.

    // Salva localmente (local-first)
    if (state.runId != null) {
      _local.addPoint(state.runId!, newPoint);
      _pendingFlushCount++;
      if (_pendingFlushCount >= _flushBatchSize) _flush();
    }
  }

  Future<void> _flush() async {
    if (state.runId == null ||
        state.points.isEmpty ||
        _isLocalRunId(state.runId!)) {
      return;
    }
    final pending = state.points.takeLast(_pendingFlushCount).toList();
    if (pending.isEmpty) return;
    try {
      await _remote.addGpsBatch(state.runId!, pending);
      _pendingFlushCount = 0;
    } catch (_) {
      // Falha silenciosa — pontos estão em Hive, serão enviados no próximo flush
    }
  }

  Future<void> _onComplete(CompleteRun event, Emitter<RunState> emit) async {
    if (state.runId == null) return;
    _pendingRotationTrigger = null;
    _bpmSub?.cancel(); _stepsSub?.cancel(); _spo2Sub?.cancel();
    _bpmSub = null;
    _bpmFallbackPollTimer?.cancel();
    _bpmFallbackPollTimer = null;
    _runHealthSyncTimer?.cancel();
    _runHealthSyncTimer = null;
    unawaited(workoutRealtimeService.stop()); unawaited(AudioSessionKeepalive.instance.stopKeepalive());
    // Empurra status=completed COM totais + splits pro Watch (em vez de idle
    // direto). Watch mostra RunCompletedScreen até user reconhecer; só aí
    // volta pra idle. Splits aqui são os locais — `computeKmSplits` final
    // roda mais abaixo após coletar pontos pendentes.
    unawaited(workoutRealtimeService.pushRunState({
      'type': 'run_state',
      'status': 'completed',
      'elapsedS': state.elapsedS,
      'distanceM': state.distanceM,
      'paceMinKm': state.currentPaceMinKm ?? 0,
      'bpm': state.currentBpm ?? 0,
      'caloriesKcal': _approxCalories(state.distanceM),
      'elevationM': _approxElevationGain(state.splits),
      'runType': state.runType ?? 'Free Run',
      'splits': state.splits
          .map((s) => {
                'km': s.kmIndex + 1,
                'durationS': s.durationS,
                'pace': s.avgPaceMinKm,
                'bpm': s.avgBpm ?? 0,
                'elev': s.elevationGain ?? 0,
              })
          .toList(),
    }));
    if (state.distanceM >= stationaryDistanceThresholdM) {
      _requestCoachCue(event: 'finish');
      // Mantém a sessão Live aberta até o resumo terminar de tocar (premium).
      // Freemium: a fala 'finish' já saiu pelo TTS local — não precisa esperar.
      if (_isPremium) {
        Timer(const Duration(seconds: 15), () {
          unawaited(_coachSession.close());
          _coachCtx.dispose();
        });
      }
    } else if (_isPremium) {
      unawaited(_coachSession.close());
      _coachCtx.dispose();
    }
    emit(state.copyWith(status: RunStatus.completing));
    _stop();

    try {
      final storageRunId = state.runId!;
      var remoteRunId = storageRunId;

      if (_isLocalRunId(storageRunId)) {
        final created = await _remote.createRun(
          type: state.runType ?? 'Free Run',
          targetPace: state.targetPace,
          targetDistance: state.targetDistance,
        );
        remoteRunId = created.id;
      }

      // Flush final de todos os pontos pendentes
      if (_pendingFlushCount > 0) {
        final pending = state.points.takeLast(_pendingFlushCount).toList();
        if (pending.isNotEmpty) {
          await _remote.addGpsBatch(remoteRunId, pending);
          _pendingFlushCount = 0;
        }
      }

      // Recompute final dos splits com os pontos completos. state.splits foi
      // atualizado por último na última travessia de km — o tail (ex: 40m
      // de uma run de 3.04km) ainda não tinha virado split. computeKmSplits
      // emite um KmSplit parcial quando há leftoverM > 100m, fechando esse gap.
      final finalSplits = computeKmSplits(state.points);

      // Calcula avgBpm e maxBpm a partir dos splits que têm BPM. Antes
      // estava enviando null/undefined e o histórico mostrava "--" pra
      // todas as runs. Fix par com GpsPoint.bpm (Q3): só funciona depois
      // que GPS points carregam o BPM live, senão splits.avgBpm fica null
      // e os agregados aqui também.
      final bpmValues = finalSplits
          .map((s) => s.avgBpm)
          .whereType<int>()
          .where((b) => b > 0)
          .toList();
      final avgBpmFromSplits = bpmValues.isEmpty
          ? null
          : (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round();
      // FIX TF 59: max real do pico instantâneo (atualizado a cada _onBpmTick),
      // não max de splits.avgBpm. User reportou pico 165 mas split-avg ficou 150
      // porque média de km esconde picos de 5-10s. `state.maxBpmSeen` tem o
      // valor cru. Fallback pra splits se BPM ao vivo falhou.
      final maxBpmFromTimeline = state.maxBpmSeen;
      final maxBpmFromSplits = bpmValues.isEmpty
          ? null
          : bpmValues.reduce(max);
      final maxBpmFinal = (maxBpmFromTimeline != null && maxBpmFromTimeline > 0)
          ? maxBpmFromTimeline
          : maxBpmFromSplits;

      final run = await _remote.completeRun(
        remoteRunId,
        distanceM: state.distanceM,
        durationS: state.elapsedS,
        avgBpm: avgBpmFromSplits,
        maxBpm: maxBpmFinal,
        splits: finalSplits,
        telemetryTimeline: state.telemetryTimeline.isEmpty
            ? null
            : state.telemetryTimeline.map((t) => t.toJson()).toList(),
      );
      await _local.clearRun(storageRunId);
      // Sessão planejada concluída → o server marcou executedRunId na sessão.
      // Invalida o cache do plano (cacheFirst na home) pra a próxima abertura
      // buscar o plano fresco e mostrar a flag "concluída".
      if (_planSessionId != null) {
        PlanRemoteDatasource.clearPlanCache();
        // Empurra today_session atualizada pro Watch com isExecuted=true,
        // pra ele trocar o botão "INICIAR SESSÃO" pelo badge verde
        // "CONCLUÍDA" sem esperar o user reabrir o prep_page. Sem isso,
        // Watch ficava com cache antigo (isExecuted=false) e o user via
        // a sessão "disponível" mesmo já tendo feito.
        unawaited(workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': {
            'type': run.type,
            'distanceKm': run.distanceM / 1000,
            'planSessionId': _planSessionId,
            'isExecuted': true,
          },
        }));
      }
      // TF 70: push EXPLÍCITO de run_state=completed pro Watch. Sem isso,
      // Watch só descobria via próximo telemetry tick (30s) — user via
      // PreRunScreen com isExecuted ainda falso até o tick chegar. Agora
      // a transição é imediata: Watch sai pra RunCompletedScreen no exato
      // momento que iPhone marca completo. _attachedTodaySession do
      // workout_realtime_service garante que o todaySession atualizado
      // (com isExecuted=true setado no push anterior) vá junto.
      unawaited(workoutRealtimeService.pushRunState({
        'type': 'run_state',
        'status': 'completed',
        'elapsedS': state.elapsedS,
        'distanceM': state.distanceM,
      }));
      emit(state.copyWith(status: RunStatus.completed, completedRun: run));
    } catch (e) {
      emit(state.copyWith(status: RunStatus.error, error: e.toString()));
    }
  }

  /// Cada sample BPM vindo do wearable. Acumula pro split do km (kmAvgBpm),
  /// atualiza maxBpmSeen, emite o state pra UI consumir, e dispara o cue
  /// high_bpm quando aplicável.
  ///
  /// Realtime (workoutRealtimeService) tem prioridade: quando chega um
  /// sample realtime, cancela o polling de fallback (se ativo) e marca
  /// bpmSource='realtime'. Fallback (healthSyncService.latestBpm) só
  /// é usado quando realtime não emitiu nada em 5s — vide _scheduleBpmFallback.
  void _onBpmTick(_BpmTick event, Emitter<RunState> emit) {
    final value = event.value;
    if (value != null && value > 0) {
      _kmBpmSamples.add(value);
      _lastBpmAtMs = DateTime.now().millisecondsSinceEpoch;
      // BPM voltou — autoriza o próximo flip pra stale a logar de novo.
      _bpmStaleLogged = false;
      final newMax = (state.maxBpmSeen == null || value > state.maxBpmSeen!)
          ? value
          : state.maxBpmSeen!;
      // Realtime ganha do fallback: se realtime sample chega, cancela o
      // polling (volta ao "modo barato"). Marca fonte na ordem certa
      // pra UI mostrar ícone correspondente.
      final source = event.fallback ? 'fallback' : 'realtime';
      if (!event.fallback) {
        _bpmFallbackPollTimer?.cancel();
        _bpmFallbackPollTimer = null;
      }
      emit(state.copyWith(
        currentBpm: value,
        maxBpmSeen: newMax,
        bpmStaleness: BpmStaleness.fresh,
        bpmSource: source,
      ));

      // high_bpm cue — gate por alertPref + maxBpm declarado + cooldown 90s.
      // Sem maxBpm não dispara (evita falsos positivos com estimativa 220-age).
      // Só roda quando run está ativa (não em paused/idle) E em realtime
      // (fallback tem latência alta — pode atrasar alerta de pico de esforço).
      if (state.status == RunStatus.active &&
          !event.fallback &&
          _alertPrefs['highBpm'] == true &&
          _userMaxBpm != null &&
          value > (_userMaxBpm! * 0.92) &&
          _cooldownOk('high_bpm', seconds: 90)) {
        // Reusa o slot `kmAvgBpm` pra passar o BPM atual; o coach
        // telemetryText cita o valor diretamente na branch high_bpm.
        unawaited(_requestCoachCue(
          event: 'high_bpm',
          kmAvgBpm: value,
        ));
        _lastCueAt['high_bpm'] = DateTime.now().millisecondsSinceEpoch;
      }
    } else {
      // Source caiu (Watch desligado, permission revogada, no_hr_source).
      // Marca como inativa pra UI exibir ícone "desativado" + "—" em vez
      // de manter o último valor mockado. Mantém o `currentBpm` no state
      // (pra historico em-memória), mas a UI usa `bpmSourceActive` pra gatear.
      _lastBpmAtMs = null;
      if (state.bpmStaleness != BpmStaleness.lost) {
        emit(state.copyWith(bpmStaleness: BpmStaleness.lost, bpmSource: 'none'));
      }
    }
  }

  /// Timestamp em ms do último sample BPM recebido. Usado em [_onTimerTick]
  /// pra calcular a [BpmStaleness] atual via [_resolveBpmStaleness].
  int? _lastBpmAtMs;

  /// Thresholds em ms pra cada degrau de staleness.
  /// `_bpmStaleAfterMs`: fresh → stale (chip mostra último valor com "?").
  /// `_bpmLostAfterMs`:  stale → lost  (chip mostra "—", restart da iOS query).
  /// Reduzido pra 8s/15s (era 15s/45s) — user reportou "perde muita conexão";
  /// 45s era pessimista demais, o gap visível de BPM frustrava. Agora detecta
  /// stale em 8s e dispara restart em 15s. Watch geralmente bate 1Hz, então
  /// 8s sem nenhum sample = problema real, vale logar/agir.
  static const _bpmStaleAfterMs = 8 * 1000;
  static const _bpmLostAfterMs = 15 * 1000;

  /// True quando já logamos `run.bpm.stale.detected` na transição atual pra
  /// stale. Reseta quando BPM volta fresh. Evita inflar analytics enquanto
  /// segue stale na mesma corrida.
  bool _bpmStaleLogged = false;

  /// Calcula o degrau de staleness pelo tempo desde o último sample.
  BpmStaleness _resolveBpmStaleness() {
    if (_lastBpmAtMs == null) return BpmStaleness.lost;
    final age = DateTime.now().millisecondsSinceEpoch - _lastBpmAtMs!;
    if (age < _bpmStaleAfterMs) return BpmStaleness.fresh;
    if (age < _bpmLostAfterMs) return BpmStaleness.stale;
    return BpmStaleness.lost;
  }

  /// Side-effects na entrada em cada degrau:
  ///   fresh: nada — só atualiza o state.
  ///   stale: 1 tentativa imediata do fallback poll (barata) + log analytics.
  ///   lost:  arranca o fallback poll periódico (se não tiver rodando) +
  ///          restart da iOS query (tentativa de resgatar HKAnchoredObjectQuery
  ///          que pode ter morrido em silêncio).
  void _onBpmStalenessTransition(BpmStaleness target) {
    switch (target) {
      case BpmStaleness.fresh:
        break;
      case BpmStaleness.stale:
        if (!_bpmStaleLogged) {
          _bpmStaleLogged = true;
          analytics.logEvent('run.bpm.stale.detected', params: {
            'elapsed_s': state.elapsedS,
            'last_source': state.bpmSource,
          });
        }
        // ignore: avoid_print
        print('run.bpm.fallback.start reason=staleness');
        unawaited(_pollBpmOnce());
        break;
      case BpmStaleness.lost:
        if (_bpmFallbackPollTimer == null && state.status == RunStatus.active) {
          // ignore: avoid_print
          print('run.bpm.fallback.start reason=lost');
          unawaited(_pollBpmOnce());
          _bpmFallbackPollTimer = Timer.periodic(
            const Duration(seconds: _bpmFallbackIntervalSec),
            (_) => _pollBpmOnce(),
          );
        }
        // Tenta resgatar a iOS query — `HKAnchoredObjectQuery` morre em
        // silêncio com alguma frequência (Watch perde sinal, app suspende).
        // Restart preserva anchor (vide plugin nativo) pra não duplicar.
        unawaited(workoutRealtimeService.restart());
        break;
    }
  }

  /// Polling de BPM via healthSyncService.latestBpm() quando o stream
  /// nativo de workout não emite (Watch offline, permission negada).
  /// Iniciado 5s após _onStart se _lastBpmAtMs ainda for null. Tickada
  /// a cada 15s. Cancelado assim que chega um sample realtime ou ao
  /// pause/complete/abandon.
  Timer? _bpmFallbackPollTimer;
  /// Warmup curto: durante a corrida, BPM precisa aparecer rápido. iPhone-only
  /// (sem Watch app companion) depende quase 100% do fallback poll porque
  /// HKAnchoredObjectQuery raramente fica vivo sem HKWorkoutSession nativa.
  /// 1s ainda dá folga pra realtime ganhar a corrida se ele funcionar.
  static const _bpmFallbackWarmupSec = 1;
  /// Polling agressivo (5s) — Apple Watch escreve BPM no HK store a ~5-10s
  /// quando em workout, ~1min idle. Polling abaixo disso é overkill.
  static const _bpmFallbackIntervalSec = 5;

  /// Sync periódico de TODOS os samples (bpm, hrv, steps...) durante a corrida
  /// ativa. Empurra dados frescos pro server (`/biometrics/samples`) sem
  /// depender da home pra rodar `syncSince`. Útil pra (a) summary do user
  /// estar updated entre corridas, (b) se o app crashar, dados parciais
  /// ficam salvos.
  Timer? _runHealthSyncTimer;
  /// 10s pra dar sensação de tempo real durante a corrida. Apple Health
  /// escreve BPM a ~5-10s quando o Watch está em workout, então um sync
  /// abaixo disso é desperdício. Custo é uma chamada HK + POST de delta.
  static const _runHealthSyncIntervalSec = 10;

  /// Avalia se vale começar a polling de fallback do BPM. Chamado 5s
  /// após _onStart pelo timer de warmup. Se realtime já emitiu sample
  /// (lastBpmAtMs != null), no-op — workoutRealtimeService está OK.
  /// Senão, agenda Timer.periodic 15s pra buscar latestBpm do health.
  void _maybeStartBpmFallbackPolling() {
    if (_lastBpmAtMs != null) {
      // Realtime já chegou — não precisa de fallback.
      return;
    }
    if (state.status != RunStatus.active) return;
    // ignore: avoid_print
    print('run.bpm.fallback.start reason=no_realtime_after_warmup');
    _bpmFallbackPollTimer?.cancel();
    _pollBpmOnce(); // primeira tentativa imediata
    _bpmFallbackPollTimer = Timer.periodic(
      const Duration(seconds: _bpmFallbackIntervalSec),
      (_) => _pollBpmOnce(),
    );
  }

  Future<void> _pollBpmOnce() async {
    if (state.status != RunStatus.active) {
      _bpmFallbackPollTimer?.cancel();
      _bpmFallbackPollTimer = null;
      return;
    }
    try {
      final bpm = await healthSyncService.latestBpm(withinSeconds: 60);
      if (bpm != null && bpm > 0 && !isClosed) {
        add(_BpmTick(bpm, fallback: true));
      }
    } catch (_) {/* silencioso — caller mostra "sem fonte" no fim */}
  }

  void _onAbandon(AbandonRun event, Emitter<RunState> emit) {
    _stop();
    _bpmSub?.cancel(); _stepsSub?.cancel(); _spo2Sub?.cancel();
    _bpmSub = null;
    _bpmFallbackPollTimer?.cancel();
    _bpmFallbackPollTimer = null;
    _runHealthSyncTimer?.cancel();
    _runHealthSyncTimer = null;
    unawaited(workoutRealtimeService.stop()); unawaited(AudioSessionKeepalive.instance.stopKeepalive());
    _pendingRotationTrigger = null;
    // Volta o Watch pra PreRunScreen.
    _pushStatusToWatch('idle');
    if (_isPremium) {
      unawaited(_coachSession.close());
      _coachCtx.dispose();
    } else {
      // Freemium: corta qualquer fala em andamento (ex: km telemetria
      // disparada logo antes do abandono).
      unawaited(TelemetryTts.instance.stop());
    }
    emit(const RunState());
  }

  /// Pause: para timer + GPS poll mas mantém runId, distância e elapsed.
  /// Status vira `paused` — UI mostra botão RETOMAR. Sem reset de state.
  /// BPM stream do wearable é pausado nativamente (workout session segue
  /// merged, sem fragmentar em N workouts na Activity Ring).
  void _onPause(PauseRun event, Emitter<RunState> emit) {
    // Marca o início do paused pra _onResume contabilizar quanto tempo
    // ficamos parados e subtrair do elapsedS (mantém wall-clock truth).
    _pauseStartMs = DateTime.now().millisecondsSinceEpoch;
    _timer?.cancel();
    _gpsPollTimer?.cancel();
    _gpsSub?.cancel();
    _motivationTimer?.cancel();
    _scheduledAnalysis?.cancel();
    _stallCheckTimer?.cancel();
    _coachRotationSafetyTimer?.cancel();
    _bpmFallbackPollTimer?.cancel();
    _runHealthSyncTimer?.cancel();
    _telemetryTickTimer?.cancel();
    _runHealthSyncTimer = null;
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
    _coachRotationSafetyTimer = null;
    _bpmFallbackPollTimer = null;
    _telemetryTickTimer = null;
    // Zera a janela de staleness BPM: ao resumir, dá warmup novo antes de
    // decidir se a fonte sumiu. Sem isso, o primeiro tick pós-resume já
    // estoura `lost` se a pausa durou >45s.
    _lastBpmAtMs = null;
    _bpmStaleLogged = false;
    unawaited(workoutRealtimeService.pause());
    emit(state.copyWith(status: RunStatus.paused));
    _pushStatusToWatch('paused');
  }

  /// Parado em 30s sem deslocamento: pausa (mesmo cleanup do _onPause) e
  /// marca noMovementPrompt pra UI abrir o dialog continuar/encerrar.
  void _onNoMovementDetected(_NoMovementDetected event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;
    _timer?.cancel();
    _gpsPollTimer?.cancel();
    _gpsSub?.cancel();
    _motivationTimer?.cancel();
    _scheduledAnalysis?.cancel();
    _stallCheckTimer?.cancel();
    _coachRotationSafetyTimer?.cancel();
    _telemetryTickTimer?.cancel();
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _telemetryTickTimer = null;
    _stallCheckTimer = null;
    _coachRotationSafetyTimer = null;
    unawaited(workoutRealtimeService.pause());
    emit(state.copyWith(status: RunStatus.paused, noMovementPrompt: true));
  }

  /// Resume: re-inicia timer + GPS poll mantendo elapsed/distância atuais.
  /// Não dispara nova saudação (coach só fala no INICIAR original).
  /// BPM stream do wearable é retomado nativamente (mesma session HK).
  Future<void> _onResume(ResumeRun event, Emitter<RunState> emit) async {
    if (state.status != RunStatus.paused) return;
    // Soma o intervalo paused em _pausedTotalMs pra _onTimerTick continuar
    // calculando elapsedS = now - startedAt - pausedTotal.
    final pauseStart = _pauseStartMs;
    if (pauseStart != null) {
      _pausedTotalMs += DateTime.now().millisecondsSinceEpoch - pauseStart;
      _pauseStartMs = null;
    }
    unawaited(workoutRealtimeService.resume());
    // Resume começa em estado neutro de BPM (lost) e a UI vai mostrar "—"
    // até o primeiro sample chegar. Sem isso a UI carrega o último staleness
    // do pause, que poderia ser `fresh` mas com sample já velho.
    _lastBpmAtMs = null;
    _bpmStaleLogged = false;
    emit(state.copyWith(
      status: RunStatus.active,
      bpmStaleness: BpmStaleness.lost,
    ));
    // Idempotência: cancela timer anterior antes de criar novo (mesmo
    // motivo do _onStart — duplo-tick em StartRun repetido).
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(_TimerTick()),
    );
    _startMotivationTimer();
    _startCoachRotationSafetyTimer();
    if (kIsWeb) {
      const webSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      );
      _gpsPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        Geolocator.getCurrentPosition(locationSettings: webSettings).then((pos) {
          if (!isClosed) add(_GpsUpdate(pos));
        }).catchError((_) {});
      });
    } else if (mockGpsService.enabled) {
      _gpsSub = mockGpsService.stream().listen((pos) => add(_GpsUpdate(pos)));
    } else {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: _runLocationSettings(),
      ).listen((pos) => add(_GpsUpdate(pos)));
    }
  }

  void _stop() {
    _gpsSub?.cancel();
    _gpsPollTimer?.cancel();
    _timer?.cancel();
    _flushTimer?.cancel();
    _motivationTimer?.cancel();
    _scheduledAnalysis?.cancel();
    _stallCheckTimer?.cancel();
    _coachRotationSafetyTimer?.cancel();
    _telemetryTickTimer?.cancel();
    // Run terminou — dispensa a notificação de background mesmo se a app
    // estava em foreground (caso o user voltou e finalizou pela UI).
    unawaited(runBgNotificationService.cancel());
    _gpsSub = null;
    _gpsPollTimer = null;
    _timer = null;
    _flushTimer = null;
    _telemetryTickTimer = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
    _coachRotationSafetyTimer = null;
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  /// Hook do WidgetsBindingObserver — dispara quando o app muda de estado
  /// (foreground ↔ background). Durante run ativa, queremos manter GPS, BPM e
  /// timer principal vivos (LocationSettings + foreground service garantem),
  /// mas pausar timers UI puros (motivation, stall, coach rotation safety)
  /// pra não desperdiçar CPU/bateria com nada renderizando.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    final goingBg = lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive ||
        lifecycle == AppLifecycleState.hidden;
    if (goingBg && !_appInBackground) {
      _appInBackground = true;
      // ignore: avoid_print
      print('run.lifecycle.background state=$lifecycle');
      _motivationTimer?.cancel();
      _motivationTimer = null;
      _stallCheckTimer?.cancel();
      _stallCheckTimer = null;
      _coachRotationSafetyTimer?.cancel();
      _coachRotationSafetyTimer = null;
      if (state.status == RunStatus.active) {
        unawaited(runBgNotificationService.update(
          distanceM: state.distanceM,
          elapsedS: state.elapsedS,
          paceMinKm: state.currentPaceMinKm,
          sessionType: state.runType,
          bpm: state.bpmSourceActive ? state.currentBpm : null, startSource: _startSource,
        ));
      }
    } else if (lifecycle == AppLifecycleState.resumed && _appInBackground) {
      _appInBackground = false;
      // ignore: avoid_print
      print('run.lifecycle.foreground');
      // Wall-clock truth no _onTimerTick já mantém elapsedS correto sem
      // catch-up — o próximo tick (em até 1s) ajusta o display. Aqui só
      // reseta a janela de BPM staleness pra evitar flag `lost` espúrio
      // no primeiro tick pós-resume.
      if (state.status == RunStatus.active) {
        _lastBpmAtMs = null;
        _bpmStaleLogged = false;
        // TF 75 Fase 9: tenta puxar BPM do cache nativo iPhone. Watch pode
        // ter empurrado samples enquanto Dart engine estava suspenso —
        // sem isso a UI ficava 5-30s exibindo BPM stale até o próximo push.
        unawaited(() async {
          final cached = await workoutRealtimeService.getLastCachedBpm();
          if (cached != null && !isClosed) {
            add(_BpmTick(cached));
          }
        }());
      }
      unawaited(runBgNotificationService.cancel());
      if (state.status == RunStatus.active) {
        _startMotivationTimer();
        _startCoachRotationSafetyTimer();
      }
    }
  }

  @override
  Future<void> close() {
    _stop();
    _coachTranscriptSub?.cancel();
    _bpmSub?.cancel(); _stepsSub?.cancel(); _spo2Sub?.cancel();
    _bpmSub = null;
    _watchStatusSub?.cancel();
    _watchStatusSub = null;
    _watchCommandSub?.cancel();
    _watchCommandSub = null;
    _watchReconnectedSub?.cancel();
    _watchReconnectedSub = null;
    _bpmFallbackPollTimer?.cancel();
    _bpmFallbackPollTimer = null;
    _runHealthSyncTimer?.cancel();
    _runHealthSyncTimer = null;
    unawaited(workoutRealtimeService.stop()); unawaited(AudioSessionKeepalive.instance.stopKeepalive());
    if (_isPremium) {
      unawaited(_coachSession.close());
      _coachCtx.dispose();
    } else {
      unawaited(TelemetryTts.instance.stop());
    }
    return super.close();
  }

  /// Resolve a PlanSession da run atual e cacheia segments pra
  /// detecção de transição em _onGpsUpdate. Busca o plano vigente e
  /// procura a sessão por id em qualquer semana. Falha silenciosa
  /// (sem plano = run roda como Free Run, sem segments).
  Future<void> _loadPlanSession(String sessionId) async {
    try {
      final plan = await _planRemote.getCurrentPlan().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          ).catchError((_) => null);
      if (plan == null || isClosed) return;
      PlanSession? found;
      // Procura no vigente primeiro; cai pra base se a sessão foi removida
      // pela revisão mas a run aponta pra ela (raro, mas válido).
      for (final week in plan.effectiveWeeks) {
        try {
          found = week.sessions.firstWhere((s) => s.id == sessionId);
          break;
        } catch (_) {/* sessão não está nessa semana */}
      }
      if (found == null) {
        for (final week in plan.weeks) {
          try {
            found = week.sessions.firstWhere((s) => s.id == sessionId);
            break;
          } catch (_) {/* tampouco no base */}
        }
      }
      if (found == null) return;
      _segments = found.executionSegments;
      // Alvo de distância vem da sessão planejada — cue goal_reached
      // dispara quando newDistance cruza isso. distanceKm vem em km double.
      _plannedDistanceM = found.distanceKm > 0 ? found.distanceKm * 1000 : null;
      // Marca o 1º segment (aquecimento) como JÁ entrado: no km 0 o detector
      // de transição não dispara segment_start pro segment inicial — a
      // saudação já anuncia a largada. Sem isso, o segment_start do warmup
      // toca por cima da saudação ("dois coaches" no início).
      if (_segments.isNotEmpty && _currentSegmentIdx < 0) {
        _currentSegmentIdx = 0;
      }
      // ignore: avoid_print
      print('coach.plan_session.loaded id=$sessionId segments=${_segments.length}');
    } catch (_) {/* sem plano, segue Free Run */}
  }

  /// True se passou `seconds` desde o último cue desse tipo (ou nunca rolou).
  /// Anti-flood pra triggers que podem disparar várias vezes.
  bool _cooldownOk(String cueType, {required int seconds}) {
    final last = _lastCueAt[cueType];
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed >= seconds * 1000;
  }

  /// Inicia timer da regra canônica POR TEMPO: a cada 4min sem o coach
  /// falar, dispara um check_in. Junto com o trigger POR DISTÂNCIA
  /// (500m, vide _onGpsUpdate), garante presença contínua do coach mesmo
  /// quando a sessão segue o plano sem alertas.
  ///
  /// Mantém o nome _startMotivationTimer e o gate _alertPrefs['motivation']
  /// (toggle do user) por compatibilidade — mas a janela mudou de 5min
  /// fixo (motivation legado) pra 4min canônico (check_in).
  void _startMotivationTimer() {
    _motivationTimer?.cancel();
    if (_alertPrefs['motivation'] != true) return;
    _motivationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.status != RunStatus.active || isClosed) return;
      if (_lastCoachSpeechAtMs == 0) return; // saudação inicial ainda não saiu
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedS = (now - _lastCoachSpeechAtMs) / 1000;
      // ignore: avoid_print
      print('coach.checkin.tick elapsedSinceLastSpeech=${elapsedS.round()}s threshold=${_checkInIdleSeconds}s');
      if (elapsedS < _checkInIdleSeconds) return;
      unawaited(_requestCoachCue(
        event: 'check_in',
        distanceM: state.distanceM,
        elapsedS: state.elapsedS,
        currentPaceMinKm: state.currentPaceMinKm,
      ));
    });
  }

  /// Safety pra rotação da sessão Live. A rotação normal é disparada
  /// por triggers naturais (km_reached/segment_start/segment_end), mas
  /// runs lentas ou em pace estável podem ficar minutos sem nenhum
  /// trigger — e o Gemini Live tem cap implícito de ~10min por sessão.
  /// Este timer tick a cada 30s e chama `_maybeRotateLiveSession` com
  /// trigger sintético; o gate `shouldRotateNow` (turns≥6 OR age≥6min)
  /// decide se de fato rotaciona. Evita silêncio pós-cap em qualquer
  /// pace de corrida.
  void _startCoachRotationSafetyTimer() {
    _coachRotationSafetyTimer?.cancel();
    // Freemium não abre LiveRunCoachSession, então não há sessão pra rotacionar.
    if (!_isPremium) return;
    _coachRotationSafetyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isClosed) return;
      if (state.status != RunStatus.active) return;
      _maybeRotateLiveSession(trigger: 'safety_age_check');
    });
  }

  /// Provoca UMA fala curta do coach na sessão Live. Toda a lógica de
  /// gatilho/cooldown/dedup fica nos call sites; aqui só formatamos a
  /// telemetria do momento e enviamos. O modelo decide O QUE dizer; o áudio
  /// e a transcrição voltam pela sessão (LiveRunCoachSession).
  Future<void> _requestCoachCue({
    required String event,
    int? kmReached,
    double? distanceM,
    int? elapsedS,
    double? currentPaceMinKm,
    double? targetPaceMinKm,
    int? currentSegmentIndex,
    int? kmDurationS,
    int? kmAvgBpm,
    double? elevationGainM,
    // Enriquece o cue `check_in` (a cada 500m): pace dos últimos 500m vs
    // alvo, e km que faltam pra meta da sessão. Permite o coach gerar as
    // 4 persona variants de "presença" (vide _telemetryText.case 'check_in').
    double? paceLast500m,
    double? kmRemaining,
  }) async {
    if (state.runId == null) return;
    // TF 75 Fase 3: cooldown global entre cues. `finish` ignora (precisa
    // falar no fim). Pre-run, motivation_timer, e os outros respeitam.
    // TF 77 F2: pre_run agora respeita cooldown (Watch+iPhone race causa 2x).
    // finish ignora — precisa falar no fim.
    if (event != 'finish') {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastAnyCoachCueAtMs < _globalCueCooldownS * 1000) {
        Logger.warn('coach.cue.suppressed_global_cooldown', context: {
          'event': event,
          'elapsedMs': '${nowMs - _lastAnyCoachCueAtMs}',
          'thresholdMs': '${_globalCueCooldownS * 1000}',
        });
        return;
      }
    }
    // Freemium: pula o backend e a sessão Live. Só `km_reached` e `finish`
    // viram telemetria falada localmente (TTS on-device) + banner. Outros
    // eventos (motivation, pace_alert, segment_*) ficam silenciosos —
    // freemium é "métrica simples", sem coach AI conversando.
    if (!_isPremium) {
      String? msg;
      if (event == 'km_reached' && kmReached != null) {
        msg = TelemetryTts.formatKmTelemetry(
          kmReached: kmReached,
          kmDurationS: kmDurationS,
          currentPaceMinKm: currentPaceMinKm,
          elapsedS: elapsedS,
        );
      } else if (event == 'finish') {
        msg = TelemetryTts.formatFinish(
          distanceM: state.distanceM,
          elapsedS: state.elapsedS,
        );
      }
      if (msg != null) {
        if (!isClosed) add(_CoachChunk(CoachCue(text: msg)));
        unawaited(TelemetryTts.instance.speak(msg));
        _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
        _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
        _lastCoachSpeechDistanceM = state.distanceM;
      }
      return;
    }
    if (!_coachSession.isOpen) {
      // TF 69: Live caiu mid-run. Antes ficava em silêncio; agora cai pro
      // HTTP /coach/message. Server resolve via templates (rev 51, zero LLM
      // pra eventos mecânicos) ou Flash + Live TTS (mesma voz Charon).
      // Latência maior (~2-3s) que o WS, mas melhor que silêncio.
      Logger.info('coach.cue.fallback_http', context: {
        'event': event,
        'kmReached': '${kmReached ?? '-'}',
      });
      unawaited(_requestCoachCueViaHttp(
        event: event,
        kmReached: kmReached,
        currentPaceMinKm: currentPaceMinKm ?? _computePaceMinKm(),
        targetPaceMinKm: targetPaceMinKm ?? _parsePaceMinKm(state.targetPace),
        kmDurationS: kmDurationS,
        kmAvgBpm: kmAvgBpm,
        currentSegmentIndex: currentSegmentIndex,
      ));
      // Trackers avançam pros eventos de tempo/distância (check_in) pra
      // não re-empilhar requests no próximo tick. Outros eventos (km_reached,
      // segment_*, pace_alert) também avançam porque o HTTP request JÁ vai
      // entregar o cue — não queremos disparar 2x.
      _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
      _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
      _lastCoachSpeechDistanceM = state.distanceM;
      return;
    }
    // Janela da saudação: não provoca falas por cima da largada.
    if (event != 'finish' &&
        DateTime.now().millisecondsSinceEpoch < _suppressCuesUntilMs) {
      Logger.info('coach.cue.skipped_suppressed', context: {
        'event': event,
        'remainingMs': '${_suppressCuesUntilMs - DateTime.now().millisecondsSinceEpoch}',
      });
      return;
    }
    // Marca o trigger pra o turn que vai chegar — o session usa pra alimentar
    // o ctxMgr e o beacon /coach/live-turn com o evento que provocou a fala.
    _coachSession.markTrigger(event);
    // Informa o tom da sessão pro context manager (idempotente): free/guide/
    // performance. Usado no preamble de rotação pra que o coach saiba o tipo
    // de sessão sem precisar inferir das métricas.
    _coachSession.setSessionTone(
      _sessionTone(state.runType, _parsePaceMinKm(state.targetPace)),
    );
    final tt = _telemetryText(
      event,
      runType: state.runType,
      kmReached: kmReached,
      kmDurationS: kmDurationS,
      currentPaceMinKm: currentPaceMinKm ?? _computePaceMinKm(),
      targetPaceMinKm: targetPaceMinKm ?? _parsePaceMinKm(state.targetPace),
      elevationGainM: elevationGainM,
      kmAvgBpm: kmAvgBpm,
      paceLast500m: paceLast500m,
      kmRemaining: kmRemaining,
    );
    // TF 75 Fase 6: trocado print por Logger.info pra ir pro Cloud Logging.
    // `print` só vai pro Console.app local; sem isso, debug remoto das
    // alucinações ("coach falou 5:42 parado") era impossível.
    final ttPreview = tt.length > 240 ? '${tt.substring(0, 240)}…' : tt;
    Logger.info('run.coach.send_telemetry', context: {
      'event': event,
      'text': ttPreview,
      'textLen': '${tt.length}',
      'runId': state.runId ?? '',
    });
    _coachSession.sendTelemetry(tt);
    // Atualiza trackers da regra canônica (500m / 4min): qualquer fala do
    // coach reseta os dois. Mantém a cadência prometida ao user mesmo quando
    // a fala foi de outro evento (km_reached, pace_alert, etc.).
    _lastCoachSpeechAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastAnyCoachCueAtMs = _lastCoachSpeechAtMs;
    _lastCoachSpeechDistanceM = state.distanceM;
  }

  /// Fallback HTTP quando Live WS está fechada (TF 69).
  /// POST /coach/message → server resolve via template determinístico (zero
  /// LLM em check_in/segment_*/goal_reached/finish) ou Flash + Live TTS pros
  /// LLM cues (km_reached/pace_alert/high_bpm). Voz Charon idêntica ao Live.
  ///
  /// Best-effort: falha silenciosa (log warn) — não trava a run, apenas
  /// significa que o user perdeu UM cue. Próximo evento tenta de novo.
  Future<void> _requestCoachCueViaHttp({
    required String event,
    int? kmReached,
    double? currentPaceMinKm,
    double? targetPaceMinKm,
    int? kmDurationS,
    int? kmAvgBpm,
    int? currentSegmentIndex,
  }) async {
    if (state.runId == null) return;
    try {
      final accumulated = StringBuffer();
      await for (final cue in _coachRemote.streamCoachCue(
        runId: state.runId,
        event: event,
        runType: state.runType,
        currentPaceMinKm: currentPaceMinKm ?? 0,
        distanceM: state.distanceM,
        elapsedS: state.elapsedS,
        targetPaceMinKm: targetPaceMinKm,
        kmReached: kmReached,
        kmDurationS: kmDurationS,
        kmAvgBpm: kmAvgBpm,
        currentSegmentIndex: currentSegmentIndex,
        planSessionId: _planSessionId,
      )) {
        if (isClosed) break;
        // Emite _CoachChunk pra que UI/state acompanhe a fala (mesma
        // semântica do caminho Live). Sem isso, banner do coach não
        // atualizaria com o texto do fallback.
        add(_CoachChunk(CoachCue(
          text: cue.text,
          audioBase64: cue.audioBase64,
          audioMimeType: cue.audioMimeType,
        )));
        if (cue.text.isNotEmpty) accumulated.write(cue.text);
        final audio = cue.audioBase64;
        if (audio != null && audio.isNotEmpty) {
          unawaited(playCoachAudio(
            audio,
            mimeType: cue.audioMimeType ?? 'audio/mpeg',
          ));
        }
      }
      // Grava no context manager pra que o preamble de rotação inclua
      // o que foi dito durante o fallback (quando a sessão Live estava fechada).
      final fullText = accumulated.toString().trim();
      if (fullText.isNotEmpty) {
        _coachSession.recordFallbackTurn(text: fullText, trigger: event);
      }
    } catch (e, st) {
      Logger.warn('coach.cue.fallback_http_failed', context: {
        'event': event,
        'err': e.toString(),
        'stack_first_line': st.toString().split('\n').first,
      });
    }
  }

  /// Em transições naturais (km_reached, segment_start, segment_end) avalia
  /// se vale rotacionar a sessão Live agora pra evitar acúmulo de contexto
  /// interno do socket (causa raiz da degradação de voz observada ~km 3).
  /// Se o user está em push-to-talk, marca pra rotacionar quando soltar.
  void _maybeRotateLiveSession({required String trigger}) {
    if (!_coachSession.isOpen) return;
    if (!_coachSession.shouldRotateNow()) return;
    if (_coachSession.isTalking) {
      _pendingRotationTrigger = trigger;
      // ignore: avoid_print
      print('run.coach.live.rotate.deferred trigger=$trigger reason=push_to_talk_active');
      return;
    }
    unawaited(_coachSession.rotateSession(reason: trigger));
  }

  RunMetricsSnapshot _buildMetricsSnapshot() {
    String? phase;
    if (_currentSegmentIdx >= 0 && _currentSegmentIdx < _segments.length) {
      phase = _segments[_currentSegmentIdx].phase;
    }
    return RunMetricsSnapshot(
      distanceKm: state.distanceM / 1000.0,
      elapsedS: state.elapsedS,
      avgPaceMinKm: _computePaceMinKm(),
      currentPaceMinKm: state.currentPaceMinKm,
      currentPhase: phase,
    );
  }

  /// Formata o turn de telemetria por momento. Frases instrucionais curtas —
  /// o estilo/objetivo já estão no systemInstruction travado pelo servidor.
  String _telemetryText(
    String event, {
    String? runType,
    int? kmReached,
    int? kmDurationS,
    double? currentPaceMinKm,
    double? targetPaceMinKm,
    double? elevationGainM,
    int? kmAvgBpm,
    double? paceLast500m,
    double? kmRemaining,
  }) {
    String pace(double? p) => p == null ? '—' : _fmtPaceMinKm(p);
    String dur(int? s) => s == null ? '—' : '${s ~/ 60}min ${s % 60}s';
    final dist = (state.distanceM / 1000).toStringAsFixed(2);
    final avgPace = _fmtPaceMinKm(_computePaceMinKm());
    final tgt = targetPaceMinKm != null ? '${pace(targetPaceMinKm)}/km' : 'livre';
    // TF 75 Fase 2: detecta idle real (Watch pedômetro reportou 0 passos h60s)
    // e prefixa o telemetry com bandeira de estado. Sem isso o LLM alucinava
    // pace (5:42, 7:38) baseado em telemetria com pace falso de drift.
    final isIdle = _isStepIdle60s() == true;
    final idlePrefix = isIdle
        ? '[ESTADO: PARADO há ~1min (Watch detectou 0 passos). NÃO mencione pace '
            'nem distância; sugira retomar.] '
        : '';

    // Totais da corrida — anexados em primeira pessoa pra o coach ter sempre
    // o panorama e nunca precisar perguntar.
    final totals = 'No total já são ${dist}km em ${dur(state.elapsedS)}, pace médio $avgPace/km.';

    // IMPORTANTE: o turn é a VOZ DO ATLETA falando com o coach, em primeira
    // pessoa, pedindo feedback. O modelo nativo trata cada turn como fala de
    // um interlocutor; se mandarmos instrução em 3ª pessoa ("dê feedback") ele
    // responde como um COLEGA ("fechei sim, e vc?"). Em 1ª pessoa ele responde
    // como COACH.
    // Classifica o tom do coach pra cues durante a sessão:
    //   - guide: easy/long/recovery/caminhada — TEM pace alvo (faixa), mas
    //     coach só INFORMA o ritmo vs alvo. Não cobra ajuste fino. Tom de
    //     companhia. "Pace tá em 6:25, alvo 6:30 — confortável, bora."
    //   - performance: tempo/progressivo/intervalado/fartlek/tiros/race-pace
    //     e sessões-meta (10K, 21K, 42K, Maratona, Meia Maratona). Pace alvo
    //     restrito; coach pede AJUSTE quando fora.
    //   - free: Free Run / Corrida Livre — sem pace alvo, coach é só guia
    //     informativo sem comparar com nada.
    final tone = _sessionTone(runType, targetPaceMinKm);

    switch (event) {
      case 'start':
        return 'Oi coach! Vou começar minha ${runType ?? 'corrida'} agora.';
      case 'km_reached':
        final m = <String>[
          'pace deste km ${pace(currentPaceMinKm)}/km',
          'alvo $tgt',
          if (kmDurationS != null) 'tempo do km ${dur(kmDurationS)}',
          if (elevationGainM != null && elevationGainM > 0)
            'elevação +${elevationGainM.toStringAsFixed(0)}m',
          if (kmAvgBpm != null) 'FC $kmAvgBpm',
        ];
        return '${idlePrefix}Coach, fechei o km $kmReached. ${m.join(', ')}. $totals';
      case 'pace_alert':
        return '${idlePrefix}Coach, meu pace está ${pace(currentPaceMinKm)}/km. Alvo: $tgt. $totals';
      case 'segment_start':
        return '${idlePrefix}Coach, entrei na próxima fase do roteiro. $totals';
      case 'segment_end':
        return '${idlePrefix}Coach, terminei a fase atual do roteiro. $totals';
      case 'motivation':
        return '${idlePrefix}Coach, como estou indo? $totals';
      case 'check_in':
        final last500 = paceLast500m != null
            ? 'pace dos últimos 500m: ${pace(paceLast500m)}/km'
            : 'mais 500m completados';
        final remaining = kmRemaining != null && kmRemaining > 0
            ? 'faltam ${kmRemaining.toStringAsFixed(1)}km'
            : null;
        // pace menor = mais rápido = acima do alvo. Tolerância 6s/km (~0.1 min/km).
        final paceDirRaw = (paceLast500m != null && targetPaceMinKm != null)
            ? (paceLast500m < targetPaceMinKm - 0.1
                ? 'acima_do_alvo'
                : paceLast500m > targetPaceMinKm + 0.1
                    ? 'abaixo_do_alvo'
                    : 'no_alvo')
            : 'livre';
        if (tone == 'free') {
          return '${idlePrefix}Coach, check-in 500m: $last500. '
              '${remaining != null ? "$remaining. " : ""}$totals';
        }
        if (tone == 'guide') {
          return '${idlePrefix}Coach, check-in 500m: $last500. Alvo $tgt (faixa). '
              'Pace vs alvo: $paceDirRaw. ${remaining != null ? "$remaining. " : ""}$totals';
        }
        // performance: pace alvo restrito
        return '${idlePrefix}Coach, check-in 500m: $last500. Alvo $tgt (restrito). '
            'Pace vs alvo: $paceDirRaw. ${remaining != null ? "$remaining. " : ""}$totals';
      case 'high_bpm':
        return 'Coach, meu BPM tá em $kmAvgBpm. $totals';
      case 'no_movement':
        return 'Coach, iniciei mas ainda não comecei a me mover.';
      case 'finish':
        return 'Coach, finalizei! Total ${dist}km em ${dur(state.elapsedS)}, pace médio $avgPace/km.';
      case 'goal_reached':
        return 'Coach, bati a meta de distância da sessão. $totals';
      default:
        return 'Coach, como estou indo? $totals';
    }
  }

  /// Classifica o tom do coach durante a sessão:
  ///   - 'guide'      : easy/long/recovery/caminhada — pace alvo é faixa,
  ///                    coach informa sem corrigir.
  ///   - 'performance': tempo/progressivo/intervalado/fartlek/tiros/race-pace
  ///                    e sessões-meta (10K/21K/42K/Maratona/Meia Maratona)
  ///                    — coach cobra ajuste fino.
  ///   - 'free'       : Corrida Livre — sem pace alvo nenhum.
  ///
  /// Tipos canônicos vêm do generate-plan use-case do server (e variantes
  /// frequentes em pt-br). Match case-insensitive por substring pra cobrir
  /// "Easy Run" / "Easy" / "easy" igualmente.
  String _sessionTone(String? runType, double? targetPaceMinKm) {
    final t = (runType ?? '').toLowerCase().trim();
    if (t.isEmpty || t == 'free run' || t == 'corrida livre' || t == 'livre') {
      return 'free';
    }
    const guideKeys = ['easy', 'long', 'recovery', 'caminhada', 'walk'];
    for (final k in guideKeys) {
      if (t.contains(k)) return 'guide';
    }
    const perfKeys = [
      'tempo', 'progressivo', 'intervalado', 'tiros', 'fartlek',
      'threshold', 'race pace', 'race-pace',
      '10k', '21k', '42k', 'maratona', 'meia maratona',
    ];
    for (final k in perfKeys) {
      if (t.contains(k)) return 'performance';
    }
    // Fallback: se chegou aqui é um tipo desconhecido. Quando tem
    // targetPace, assume guide (mais seguro pra não cobrar à toa);
    // sem targetPace, free.
    return targetPaceMinKm != null ? 'guide' : 'free';
  }

  String _fmtPaceMinKm(double p) {
    final m = p.floor();
    final s = ((p - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double _computePaceMinKm() {
    if (state.currentPaceMinKm != null && state.currentPaceMinKm! > 0) {
      return state.currentPaceMinKm!;
    }
    if (state.distanceM <= 0 || state.elapsedS <= 0) return 0;
    final secondsPerKm = state.elapsedS / (state.distanceM / 1000);
    return secondsPerKm / 60;
  }

  double? _parsePaceMinKm(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    final mmss = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value);
    if (mmss != null) {
      final mm = int.tryParse(mmss.group(1)!);
      final ss = int.tryParse(mmss.group(2)!);
      if (mm == null || ss == null) return null;
      return mm + (ss / 60);
    }
    return double.tryParse(value.replaceAll(',', '.'));
  }

  bool _isLocalRunId(String runId) => runId.startsWith('local_');

  String _buildLocalRunId() {
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }
}

extension _ListExt<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
