import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnin/core/audio/telemetry_tts.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_local_datasource.dart';
import 'package:runnin/core/debug/mock_gps_service.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/notifications/run_bg_notification_service.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/data/live_run_coach_session.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/coach_live/data/coach_context_manager.dart';
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
  StartRun({
    required this.type,
    this.targetPace,
    this.targetDistance,
    this.alertPrefs,
    this.planSessionId,
    this.isPremium,
  });
}

class _GpsUpdate extends RunEvent {
  final Position pos;
  _GpsUpdate(this.pos);
}

class _TimerTick extends RunEvent {}

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
class _BpmTick extends RunEvent {
  final int? value;
  _BpmTick(this.value);
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
  /// True quando a fonte BPM (Watch/strap) emitiu sample nos últimos
  /// [BPM_STALE_SECONDS]s. False quando o wearable caiu / perdeu conexão /
  /// nunca emitiu. UI usa pra exibir ícone "desativado" em vez de manter
  /// o último valor cacheado (que dava sensação de valor mockado).
  final bool bpmSourceActive;

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
    this.bpmSourceActive = false,
  });

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
    bool? bpmSourceActive,
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
    bpmSourceActive: bpmSourceActive ?? this.bpmSourceActive,
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
  // Contexto do coach sobrevive à rotação/queda da sessão Live (source-of-truth
  // do histórico curto pra reinjetar como preamble quando a sessão é reciclada).
  final _coachCtx = CoachContextManager();
  // Sessão Gemini Live efêmera/rotacional: rotaciona em transições naturais
  // pra evitar acúmulo de áudio no histórico interno do socket (que degradava
  // a voz por volta do km 3 no modelo native-audio).
  late final LiveRunCoachSession _coachSession = LiveRunCoachSession(
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

  /// Janela da saudação inicial: até este timestamp (ms) os cues de
  /// `/coach/message` são suprimidos pra NÃO tocarem por cima da saudação
  /// (Live) — evita "dois coaches" no início. A saudação já anuncia a sessão.
  int _suppressCuesUntilMs = 0;

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
  Timer? _motivationTimer;
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
  double? _lastKmPace; // pace médio do km anterior pra splits

  // BPM realtime (workout_realtime_service). Subscription ativa durante
  // active+paused; cancela no complete/abandon. Samples acumulados por km
  // pra calcular kmAvgBpm que vai pro coach cue km_reached. _userMaxBpm
  // carregado em _onStart do profile pra gatear o cue high_bpm.
  StreamSubscription<int?>? _bpmSub;
  final List<int> _kmBpmSamples = [];
  int? _userMaxBpm;

  // Lifecycle: true quando o app está em background (paused/inactive/hidden).
  // Usado pra suprimir TTS/voice em bg (não brigar com Spotify) e pra logger.
  bool _appInBackground = false;
  bool _observerRegistered = false;

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
    _bpmSub?.cancel();
    _bpmSub = workoutRealtimeService.bpmStream.listen(
      (v) => add(_BpmTick(v)),
    );
    unawaited(workoutRealtimeService.start());

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
    _lastKmPace = null;
    _planSessionId = event.planSessionId;
    _segments = const [];
    _currentSegmentIdx = -1;
    // Premium: usa LiveRunCoachSession (Gemini Live). Freemium: TTS local
    // de telemetria a cada km. Default true mantém retro-compat se um
    // caller antigo não passar o flag.
    _isPremium = event.isPremium ?? true;
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

      _lastCoachKm = 0;
      _lastKmStartElapsedS = 0;
      _pendingRotationTrigger = null;
      if (_isPremium) {
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
            final ok = await _coachSession.open(
              planSessionId: _planSessionId,
              runId: startRunId,
            );
            if (ok && !isClosed) {
              _coachSession.markTrigger('start');
              _coachSession.sendTelemetry(_telemetryText('start', runType: startType));
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
      }

      // Timer de tempo decorrido
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(_TimerTick()),
      );

      // Motivação: dispara cue a cada 5min se não houver outro cue ativo.
      // Respeita _alertPrefs['motivation'] (no-op se false).
      _startMotivationTimer();

      // Safety pra rotação Live: garante que a sessão não estoure o cap
      // do Gemini (~10min) mesmo em runs lentas ou sem transições de
      // segmento. Roda a cada 30s e tenta rotacionar se shouldRotateNow.
      _startCoachRotationSafetyTimer();

      // Stall check: 30s após START, se distância < 5m E houve fix GPS,
      // pede ao coach um disclaimer gentil ("tudo bem? começa quando puder").
      // One-shot — reset por StartRun (não dispara em resume).
      _stallCueFired = false;
      _stallCheckTimer?.cancel();
      _stallCheckTimer = Timer(const Duration(seconds: 30), () {
        if (isClosed || _stallCueFired) return;
        if (state.status != RunStatus.active) return;
        if (state.distanceM >= 5.0) return; // moveu, OK
        _stallCueFired = true;
        // Disclaimer gentil do coach (só se houve fix GPS pra contextualizar).
        if (state.points.isNotEmpty) {
          unawaited(_requestCoachCue(
            event: 'no_movement',
            distanceM: state.distanceM,
            elapsedS: state.elapsedS,
            currentPaceMinKm: state.currentPaceMinKm,
          ));
          _lastCueAt['no_movement'] = DateTime.now().millisecondsSinceEpoch;
        }
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

  void _onTimerTick(_TimerTick event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;
    // Staleness check: se o último sample BPM foi há mais de _bpmStaleThresholdMs,
    // marca a fonte como inativa pra UI exibir "—" em vez de manter valor
    // antigo. Watch pode escrever samples esporádicos (1 a cada poucos
    // segundos) — 20s tolera bem isso e ainda detecta perda real.
    final bpmStale = _lastBpmAtMs != null &&
        DateTime.now().millisecondsSinceEpoch - _lastBpmAtMs! > _bpmStaleThresholdMs;
    if (bpmStale && state.bpmSourceActive) {
      emit(state.copyWith(
        elapsedS: state.elapsedS + 1,
        bpmSourceActive: false,
      ));
      return;
    }
    emit(state.copyWith(elapsedS: state.elapsedS + 1));
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
    );

    // Calcula distância incremental
    double addedDistance = 0;
    if (state.points.isNotEmpty) {
      final last = state.points.last;
      final accurateEnough =
          pos.accuracy <= _accuracyThreshold &&
          last.accuracy <= _accuracyThreshold;
      if (accurateEnough) {
        addedDistance = Geolocator.distanceBetween(
          last.lat,
          last.lng,
          pos.latitude,
          pos.longitude,
        );
      }
    }

    final newPoints = [...state.points, newPoint];
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

    if (crossedKmBoundary) {
      final prevKm = _lastCoachKm;
      _lastCoachKm = kmReached;
      // Atualiza notif persistente (se app está em bg) com distância nova.
      // Em foreground, _appInBackground=false e o service só atualiza o
      // payload existente — o sistema OS decide se mostra/atualiza.
      if (_appInBackground) {
        unawaited(runBgNotificationService.show(
          distanceM: newDistance,
          elapsedS: state.elapsedS,
        ));
      }
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
        // UMA fala por km: pace + tempo do km + ganho de elevação, e o coach
        // compara com a fase do roteiro (contexto vem no systemInstruction).
        unawaited(_requestCoachCue(
          event: 'km_reached',
          kmReached: kmReached,
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          kmDurationS: kmDurationS,
          kmAvgBpm: kmAvgBpm,
          elevationGainM:
              updatedSplits.isNotEmpty ? updatedSplits.last.elevationGain : null,
        ));
        _lastCueAt['km_reached'] = DateTime.now().millisecondsSinceEpoch;
        _maybeRotateLiveSession(trigger: 'km_reached');
      }
      // kmSplits: ao fechar um km, manda delta de pace vs km anterior.
      // Só dispara do 2º km em diante (precisa ter referência).
      if (_alertPrefs['kmSplits'] == true && prevKm > 0 && smoothedPace != null && _lastKmPace != null) {
        unawaited(_requestCoachCue(
          event: 'km_split',
          kmReached: kmReached,
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          targetPaceMinKm: _lastKmPace,
        ));
        _lastCueAt['km_split'] = DateTime.now().millisecondsSinceEpoch;
      }
      _lastKmPace = smoothedPace;
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
      // ativo tem targetPace. Cooldown 60s pra evitar flood.
      if (_alertPrefs['paceOutOfRange'] == true &&
          activeSegment?.targetPace != null &&
          smoothedPace != null &&
          state.status == RunStatus.active &&
          _cooldownOk('segment_pace_off', seconds: 60)) {
        final segTarget = _parsePaceMinKm(activeSegment!.targetPace);
        if (segTarget != null) {
          final deviation = (smoothedPace - segTarget).abs() / segTarget;
          if (deviation >= 0.10) {
            _requestCoachCue(
              event: 'segment_pace_off',
              currentPaceMinKm: smoothedPace,
              targetPaceMinKm: segTarget,
              distanceM: newDistance,
              elapsedS: state.elapsedS,
              currentSegmentIndex: activeSegmentIdx,
            );
            _lastCueAt['segment_pace_off'] = DateTime.now().millisecondsSinceEpoch;
          }
        }
      }
    }

    // Pace alert legado: dispara só quando NÃO há segment ativo com
    // targetPace (Free Run ou segment de warmup/cooldown sem alvo). 60s
    // cooldown como antes.
    if (!hasSegments || activeSegment?.targetPace == null) {
      if (_alertPrefs['paceOutOfRange'] == true &&
          smoothedPace != null &&
          state.targetPace != null &&
          state.status == RunStatus.active &&
          _cooldownOk('pace_alert', seconds: 60)) {
        final targetPace = _parsePaceMinKm(state.targetPace);
        if (targetPace != null) {
          final deviation = (smoothedPace - targetPace).abs() / targetPace;
          if (deviation >= 0.10) {
            _requestCoachCue(
              event: 'pace_alert',
              currentPaceMinKm: smoothedPace,
              targetPaceMinKm: targetPace,
              distanceM: newDistance,
              elapsedS: state.elapsedS,
            );
            _lastCueAt['pace_alert'] = DateTime.now().millisecondsSinceEpoch;
          }
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
    _bpmSub?.cancel();
    _bpmSub = null;
    unawaited(workoutRealtimeService.stop());
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

      final run = await _remote.completeRun(
        remoteRunId,
        distanceM: state.distanceM,
        durationS: state.elapsedS,
        splits: finalSplits,
      );
      await _local.clearRun(storageRunId);
      // Sessão planejada concluída → o server marcou executedRunId na sessão.
      // Invalida o cache do plano (cacheFirst na home) pra a próxima abertura
      // buscar o plano fresco e mostrar a flag "concluída".
      if (_planSessionId != null) {
        PlanRemoteDatasource.clearPlanCache();
      }
      emit(state.copyWith(status: RunStatus.completed, completedRun: run));
    } catch (e) {
      emit(state.copyWith(status: RunStatus.error, error: e.toString()));
    }
  }

  /// Cada sample BPM vindo do wearable. Acumula pro split do km (kmAvgBpm),
  /// atualiza maxBpmSeen, emite o state pra UI consumir, e dispara o cue
  /// high_bpm quando aplicável (substitui o TODO histórico de high_bpm
  /// que aguardava stream do wearable).
  void _onBpmTick(_BpmTick event, Emitter<RunState> emit) {
    final value = event.value;
    if (value != null && value > 0) {
      _kmBpmSamples.add(value);
      _lastBpmAtMs = DateTime.now().millisecondsSinceEpoch;
      final newMax = (state.maxBpmSeen == null || value > state.maxBpmSeen!)
          ? value
          : state.maxBpmSeen!;
      emit(state.copyWith(
        currentBpm: value,
        maxBpmSeen: newMax,
        bpmSourceActive: true,
      ));

      // high_bpm cue — gate por alertPref + maxBpm declarado + cooldown 90s.
      // Sem maxBpm não dispara (evita falsos positivos com estimativa 220-age).
      // Só roda quando run está ativa (não em paused/idle).
      if (state.status == RunStatus.active &&
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
      if (state.bpmSourceActive) {
        emit(state.copyWith(bpmSourceActive: false));
      }
    }
  }

  /// Timestamp em ms do último sample BPM recebido. Usado em [_onTimerTick]
  /// pra marcar a fonte como inativa após [_bpmStaleThresholdMs] sem update.
  int? _lastBpmAtMs;
  static const _bpmStaleThresholdMs = 20 * 1000; // 20s sem sample → stale

  void _onAbandon(AbandonRun event, Emitter<RunState> emit) {
    _stop();
    _bpmSub?.cancel();
    _bpmSub = null;
    unawaited(workoutRealtimeService.stop());
    _pendingRotationTrigger = null;
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
    _timer?.cancel();
    _gpsPollTimer?.cancel();
    _gpsSub?.cancel();
    _motivationTimer?.cancel();
    _scheduledAnalysis?.cancel();
    _stallCheckTimer?.cancel();
    _coachRotationSafetyTimer?.cancel();
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
    _coachRotationSafetyTimer = null;
    unawaited(workoutRealtimeService.pause());
    emit(state.copyWith(status: RunStatus.paused));
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
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
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
    unawaited(workoutRealtimeService.resume());
    emit(state.copyWith(status: RunStatus.active));
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
    // Run terminou — dispensa a notificação de background mesmo se a app
    // estava em foreground (caso o user voltou e finalizou pela UI).
    unawaited(runBgNotificationService.cancel());
    _gpsSub = null;
    _gpsPollTimer = null;
    _timer = null;
    _flushTimer = null;
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
      // Notificação persistente na bandeja/lock screen pra confirmar
      // visualmente que a run continua trackeada com app em background.
      // Só dispara se a run está rodando — pausada ou idle não polui o
      // centro de notificações.
      if (state.status == RunStatus.active) {
        unawaited(runBgNotificationService.show(
          distanceM: state.distanceM,
          elapsedS: state.elapsedS,
        ));
      }
    } else if (lifecycle == AppLifecycleState.resumed && _appInBackground) {
      _appInBackground = false;
      // ignore: avoid_print
      print('run.lifecycle.foreground');
      // App de volta ao primeiro plano: notificação não tem mais propósito.
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
    _bpmSub?.cancel();
    _bpmSub = null;
    unawaited(workoutRealtimeService.stop());
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
      for (final week in plan.weeks) {
        try {
          found = week.sessions.firstWhere((s) => s.id == sessionId);
          break;
        } catch (_) {/* sessão não está nessa semana */}
      }
      if (found == null) return;
      _segments = found.executionSegments;
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

  /// Inicia timer de motivação: a cada 5min, se nenhum outro cue rolou
  /// nos últimos 5min, dispara um cue motivacional. Mantém o coach
  /// presente em corridas longas sem outros gatilhos.
  void _startMotivationTimer() {
    _motivationTimer?.cancel();
    if (_alertPrefs['motivation'] != true) return;
    // Tick a cada 60s — decisão de disparar é feita em runtime baseada em
    // "stationary" detection. Antes era Timer.periodic(5min) que perdia o
    // primeiro ciclo se user estava na tela mas nada mais acontecia.
    _motivationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (state.status != RunStatus.active || isClosed) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastAny = _lastCueAt.values.fold<int>(0, (a, b) => a > b ? a : b);
      final elapsedSinceLastCue = now - lastAny;
      final isStationary = _isStationary();
      // Web stationary (typical em teste no desktop): 3min sem cue → motiva.
      // Native ou web em movimento: mantém 5min legado.
      final cooldownMs = (kIsWeb && isStationary) ? 3 * 60 * 1000 : 5 * 60 * 1000;
      // ignore: avoid_print
      print('coach.motivation.tick stationary=$isStationary elapsedSinceLastCue=${(elapsedSinceLastCue / 1000).round()}s cooldown=${cooldownMs ~/ 1000}s');
      if (elapsedSinceLastCue < cooldownMs) return;
      unawaited(_requestCoachCue(event: 'motivation'));
      _lastCueAt['motivation'] = now;
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

  /// True se os últimos pontos GPS variam menos de 20m nos últimos 60s.
  /// Web (WiFi triangulation) tipicamente fica jitterando ±5-10m sem
  /// movimento real — esse threshold filtra ruído mas captura caminhada.
  /// Sem pontos suficientes: assume stationary (conservador pra liberar
  /// motivation cedo no início).
  bool _isStationary() {
    if (state.points.length < 2) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - 60 * 1000;
    final recent = state.points.where((p) => p.ts >= cutoff).toList();
    if (recent.length < 2) return true;
    final first = recent.first;
    double maxDist = 0;
    for (final p in recent) {
      final d = Geolocator.distanceBetween(first.lat, first.lng, p.lat, p.lng);
      if (d > maxDist) maxDist = d;
    }
    return maxDist < 20.0;
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
  }) async {
    if (state.runId == null) return;
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
      }
      return;
    }
    if (!_coachSession.isOpen) {
      Logger.warn('coach.cue.skipped_session_closed', context: {
        'event': event,
        'kmReached': '${kmReached ?? '-'}',
      });
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
    _coachSession.sendTelemetry(_telemetryText(
      event,
      runType: state.runType,
      kmReached: kmReached,
      kmDurationS: kmDurationS,
      currentPaceMinKm: currentPaceMinKm ?? _computePaceMinKm(),
      targetPaceMinKm: targetPaceMinKm ?? _parsePaceMinKm(state.targetPace),
      elevationGainM: elevationGainM,
      kmAvgBpm: kmAvgBpm,
    ));
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
  }) {
    String pace(double? p) => p == null ? '—' : _fmtPaceMinKm(p);
    String dur(int? s) => s == null ? '—' : '${s ~/ 60}min ${s % 60}s';
    final dist = (state.distanceM / 1000).toStringAsFixed(2);
    final avgPace = _fmtPaceMinKm(_computePaceMinKm());
    final tgt = targetPaceMinKm != null ? '${pace(targetPaceMinKm)}/km' : 'livre';

    // Totais da corrida — anexados em primeira pessoa pra o coach ter sempre
    // o panorama e nunca precisar perguntar.
    final totals = 'No total já são ${dist}km em ${dur(state.elapsedS)}, pace médio $avgPace/km.';

    // IMPORTANTE: o turn é a VOZ DO ATLETA falando com o coach, em primeira
    // pessoa, pedindo feedback. O modelo nativo trata cada turn como fala de
    // um interlocutor; se mandarmos instrução em 3ª pessoa ("dê feedback") ele
    // responde como um COLEGA ("fechei sim, e vc?"). Em 1ª pessoa ele responde
    // como COACH.
    switch (event) {
      case 'start':
        return 'Oi coach! Vou começar agora minha ${runType ?? 'corrida'}. Me recebe e me dá a largada com o foco de hoje.';
      case 'km_reached':
        final m = <String>[
          'pace deste km ${pace(currentPaceMinKm)}/km',
          'pace alvo $tgt',
          if (kmDurationS != null) 'tempo do km ${dur(kmDurationS)}',
          if (elevationGainM != null && elevationGainM > 0)
            'ganho de elevação +${elevationGainM.toStringAsFixed(0)}m',
          if (kmAvgBpm != null) 'frequência cardíaca $kmAvgBpm',
        ];
        return 'Coach, como estou indo? Acabei de fechar o km $kmReached: ${m.join(', ')}. $totals';
      case 'km_split':
        return 'Coach, fechei o km $kmReached em ${pace(currentPaceMinKm)}/km (o km anterior foi ${pace(targetPaceMinKm)}/km). Acelerei, mantive ou caí? $totals';
      case 'pace_alert':
        return 'Coach, meu pace está ${pace(currentPaceMinKm)}/km e o alvo é $tgt. Me corrige? $totals';
      case 'segment_pace_off':
        return 'Coach, na fase atual do roteiro meu pace está ${pace(currentPaceMinKm)}/km mas o alvo da fase é $tgt. Como ajusto? $totals';
      case 'segment_start':
        return 'Coach, entrei na próxima fase do roteiro. O que muda agora? $totals';
      case 'segment_end':
        return 'Coach, terminei a fase atual do roteiro. Como fui? $totals';
      case 'motivation':
        return 'Coach, como estou indo? $totals Me dá um gás pra manter a constância.';
      case 'high_bpm':
        return 'Coach, meu BPM tá em $kmAvgBpm — acima do meu limite confortável. Devo segurar o ritmo?';
      case 'no_movement':
        return 'Coach, apertei iniciar mas ainda não comecei a me mexer. Tudo certo pra largar?';
      case 'finish':
        return 'Coach, terminei a corrida! Total ${dist}km em ${dur(state.elapsedS)}, pace médio $avgPace/km. Me dá o resumo geral.';
      default:
        return 'Coach, como estou indo? $totals';
    }
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
