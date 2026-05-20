import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_local_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/data/live_coach_voice_service.dart';
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
  StartRun({
    required this.type,
    this.targetPace,
    this.targetDistance,
    this.alertPrefs,
    this.planSessionId,
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

/// Limpa o flag do dialog de "parado" (ex: ao escolher continuar/encerrar).
class DismissNoMovementPrompt extends RunEvent {}

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
class RunBloc extends Bloc<RunEvent, RunState> {
  final _remote = RunRemoteDatasource();
  final _coachRemote = RunCoachRemoteDatasource();
  final _userRemote = UserRemoteDatasource();
  final _liveVoice = LiveCoachVoiceService();
  final _local = RunLocalDatasource();
  final _planRemote = PlanRemoteDatasource();

  StreamSubscription<Position>? _gpsSub;
  /// Web only: timer de polling pra getCurrentPosition (browser nao
  /// emite stream sem movimento real). Native usa _gpsSub direto.
  Timer? _gpsPollTimer;
  Timer? _timer;
  Timer? _flushTimer;
  int _pendingFlushCount = 0;
  bool _coachRequestInFlight = false;
  /// Timestamp em ms quando o cue atual começou — usado pra log de diagnostic
  /// quando outro cue tenta disparar e é skipado (mostra quanto tempo o
  /// anterior está pendurado). Null quando nenhum cue rodando.
  int? _coachRequestStartedAt;
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
    on<DismissNoMovementPrompt>(
      (e, emit) => emit(state.copyWith(noMovementPrompt: false)),
    );
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
      } catch (_) {/* mantém defaults */}
    }
    // ignore: avoid_print
    print('coach.alert_prefs.resolved=$_alertPrefs');
    _lastCueAt.clear();
    _lastKmPace = null;
    _planSessionId = event.planSessionId;
    _segments = const [];
    _currentSegmentIdx = -1;

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
      // Saudação inicial via Gemini Live DIRETO (sem /coach/message).
      // App fala com Live → recebe áudio WAV → toca. Sem proxy, sem TTS
      // estático, sem 504 no Cloud Run. Roda em background.
      // Suprime cues de /coach/message por 12s pra a saudação tocar SOZINHA
      // (senão segment_start/km do início tocam por cima = "dois coaches").
      _suppressCuesUntilMs = DateTime.now().millisecondsSinceEpoch + 12000;
      unawaited(_speakStartGreeting(event.type));

      // Timer de tempo decorrido
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(_TimerTick()),
      );

      // Motivação: dispara cue a cada 5min se não houver outro cue ativo.
      // Respeita _alertPrefs['motivation'] (no-op se false).
      _startMotivationTimer();

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
      } else {
        _gpsSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) => add(_GpsUpdate(pos)));

        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
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
    emit(state.copyWith(elapsedS: state.elapsedS + 1));
  }

  void _onCoachChunk(_CoachChunk event, Emitter<RunState> emit) {
    final cue = event.cue;
    // Banner do coach atualiza imediato com o texto. Áudio: se o cue
    // já vier com audioBase64 (saudação via _speakStartGreeting OU
    // legado /coach/message), toca direto. Caso contrário (cues
    // automáticos pós-saudação devem vir só com texto), sintetiza via
    // Live e despacha um novo chunk pra reativar o listener de player.
    emit(
      state.copyWith(
        coachLiveMessage: cue.text,
        coachAudioBase64: cue.audioBase64 ?? '',
        coachAudioMimeType: cue.audioMimeType ?? '',
      ),
    );
    final hasAudio = (cue.audioBase64 ?? '').isNotEmpty;
    if (!hasAudio && cue.text.isNotEmpty) {
      unawaited(_synthesizeAndDispatch(cue.text));
    }
  }

  /// Sintetiza texto via Gemini Live (client→Google direto) e despacha
  /// novo `_CoachChunk` carregando o áudio. UI player escuta.
  Future<void> _synthesizeAndDispatch(String text) async {
    try {
      final audio = await _liveVoice.synthesize(text);
      if (audio == null || isClosed) return;
      add(_CoachChunk(CoachCue(
        text: text,
        audioBase64: audio.audioBase64,
        audioMimeType: audio.mimeType,
      )));
    } catch (_) {/* sem áudio, banner segue */}
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

    // Pace suavizado (média móvel dos últimos 3 pontos com speed)
    final recentPaces = newPoints.reversed
        .where((p) => p.pace != null)
        .take(3)
        .map((p) => p.pace!)
        .toList();
    final smoothedPace = recentPaces.isEmpty
        ? null
        : recentPaces.reduce((a, b) => a + b) / recentPaces.length;

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
      // Tempo do km que acabou de cruzar (não acumulado). Coach reporta
      // "1 km em X min" + server estima calorias do km (MET × peso × tempo).
      final kmDurationS = state.elapsedS - _lastKmStartElapsedS;
      _lastKmStartElapsedS = state.elapsedS;
      // Cue 1: km_reached (info imediato sobre o km que acabou).
      // _lastCoachKm já dedup (1x por km), sem cooldown adicional.
      if (_alertPrefs['kmAlert'] == true) {
        unawaited(_requestCoachCue(
          event: 'km_reached',
          kmReached: kmReached,
          distanceM: newDistance,
          elapsedS: state.elapsedS,
          currentPaceMinKm: smoothedPace,
          kmDurationS: kmDurationS,
        ));
        _lastCueAt['km_reached'] = DateTime.now().millisecondsSinceEpoch;

        // Cue 2: km_analysis (técnico, ~10s depois). Análise compara
        // splits recentes com alvo do plano e sugere ação ("acelerar",
        // "manter", "recuperar"). LLM tem recentSplits[] como insumo.
        // Cancela cue agendado anterior se ainda pendente — só 1 análise
        // por km.
        _scheduledAnalysis?.cancel();
        _scheduledAnalysis = Timer(const Duration(seconds: 10), () {
          if (state.status != RunStatus.active || isClosed) return;
          final recent = updatedSplits
              .skip(updatedSplits.length > 5 ? updatedSplits.length - 5 : 0)
              .map((s) => s.toCoachPayload())
              .toList();
          unawaited(_requestCoachCue(
            event: 'km_analysis',
            kmReached: kmReached,
            distanceM: state.distanceM,
            elapsedS: state.elapsedS,
            currentPaceMinKm: state.currentPaceMinKm,
            recentSplits: recent,
          ));
          _lastCueAt['km_analysis'] = DateTime.now().millisecondsSinceEpoch;
        });
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
    // TODO highBpm: depende de stream do wearable (Bluetooth/HealthKit).
    // Quando stream chegar, gate similar: if (_alertPrefs['highBpm'] &&
    // bpm > maxBpm * 0.92) _requestCoachCue(event: 'high_bpm', ...);

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
    if (state.distanceM >= stationaryDistanceThresholdM) {
      _requestCoachCue(event: 'finish');
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

      final run = await _remote.completeRun(
        remoteRunId,
        distanceM: state.distanceM,
        durationS: state.elapsedS,
        splits: state.splits,
      );
      await _local.clearRun(storageRunId);
      emit(state.copyWith(status: RunStatus.completed, completedRun: run));
    } catch (e) {
      emit(state.copyWith(status: RunStatus.error, error: e.toString()));
    }
  }

  void _onAbandon(AbandonRun event, Emitter<RunState> emit) {
    _stop();
    emit(const RunState());
  }

  /// Pause: para timer + GPS poll mas mantém runId, distância e elapsed.
  /// Status vira `paused` — UI mostra botão RETOMAR. Sem reset de state.
  void _onPause(PauseRun event, Emitter<RunState> emit) {
    _timer?.cancel();
    _gpsPollTimer?.cancel();
    _gpsSub?.cancel();
    _motivationTimer?.cancel();
    _scheduledAnalysis?.cancel();
    _stallCheckTimer?.cancel();
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
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
    _timer = null;
    _gpsPollTimer = null;
    _gpsSub = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
    emit(state.copyWith(status: RunStatus.paused, noMovementPrompt: true));
  }

  /// Resume: re-inicia timer + GPS poll mantendo elapsed/distância atuais.
  /// Não dispara nova saudação (coach só fala no INICIAR original).
  Future<void> _onResume(ResumeRun event, Emitter<RunState> emit) async {
    if (state.status != RunStatus.paused) return;
    emit(state.copyWith(status: RunStatus.active));
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(_TimerTick()),
    );
    _startMotivationTimer();
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
    } else {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
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
    _gpsSub = null;
    _gpsPollTimer = null;
    _timer = null;
    _flushTimer = null;
    _motivationTimer = null;
    _scheduledAnalysis = null;
    _stallCheckTimer = null;
    _coachRequestInFlight = false;
    _coachRequestStartedAt = null;
  }

  @override
  Future<void> close() {
    _stop();
    return super.close();
  }

  /// Saudação inicial via Gemini Live (client → Gemini direto, sem
  /// proxy server). Texto montado localmente a partir do perfil em
  /// cache (UserRemoteDatasource). Falha silenciosa — UI segue mesmo
  /// se Live indisponível.
  Future<void> _speakStartGreeting(String runType) async {
    try {
      // Profile + plano em paralelo — economiza ~300-500ms vs sequencial.
      final results = await Future.wait<dynamic>([
        _userRemote.getMe().timeout(
              const Duration(seconds: 3),
              onTimeout: () => null,
            ),
        _planRemote.getCurrentPlan().timeout(
              const Duration(seconds: 3),
              onTimeout: () => null,
            ).catchError((_) => null),
      ]);
      final profile = results[0];
      final plan = results[1] as Plan?;

      final fullName = (profile?.name as String?)?.trim() ?? '';
      final firstName = fullName.isEmpty
          ? null
          : fullName.split(RegExp(r'\s+')).first;

      // Sessão planejada pra hoje (se houver plano ativo).
      PlanSession? todaySession;
      if (plan != null && plan.isReady && plan.weeks.isNotEmpty) {
        final today = DateTime.now().weekday; // 1=Mon..7=Sun
        final daysFromStart = DateTime.now().difference(plan.effectiveStartDate).inDays;
        final weekIdx = (daysFromStart / 7).floor().clamp(0, plan.weeks.length - 1);
        final week = plan.weeks[weekIdx];
        try {
          todaySession = week.sessions.firstWhere((s) => s.dayOfWeek == today);
        } catch (_) {/* sem sessão hoje */}
      }

      // Tipo escolhido pelo user (Free Run ou tipo do plano).
      final typeLower = runType.toLowerCase();
      final isFree = typeLower.contains('free');
      final typeNice = typeLower.replaceFirst('free run', 'corrida livre');

      // Monta contexto da sessão pra greeting natural.
      final ctxParts = <String>[];
      if (todaySession != null) {
        final km = todaySession.distanceKm.toStringAsFixed(
          todaySession.distanceKm % 1 == 0 ? 0 : 1,
        );
        if (isFree) {
          // User escolheu Free Run mesmo tendo plano hoje — coach reconhece.
          ctxParts.add('Você tinha planejado ${todaySession.type.toLowerCase()} de ${km}km hoje, mas escolheu corrida livre');
        } else {
          ctxParts.add('Hoje é ${todaySession.type.toLowerCase()} de ${km}km');
          if (todaySession.targetPace != null) {
            ctxParts.add('pace alvo ${todaySession.targetPace}/km');
          }
        }
      } else {
        // Sem plano OU sem sessão hoje
        ctxParts.add(isFree ? 'Corrida livre, sem distância pré-definida' : 'Começando a $typeNice');
      }

      final nameStr = firstName != null && firstName.isNotEmpty ? ', $firstName' : '';
      final greeting = 'Bora$nameStr! ${ctxParts.join('. ')}. Vou te acompanhar do início ao fim.';

      // ignore: avoid_print
      print('coach.greeting.text=$greeting');

      final audio = await _liveVoice.synthesize(greeting);
      if (audio == null || isClosed) return;
      add(_CoachChunk(CoachCue(
        text: greeting,
        audioBase64: audio.audioBase64,
        audioMimeType: audio.mimeType,
      )));
    } catch (_) {
      // best-effort; sem saudação em caso de erro
    }
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

  Future<void> _requestCoachCue({
    required String event,
    int? kmReached,
    double? distanceM,
    int? elapsedS,
    double? currentPaceMinKm,
    double? targetPaceMinKm,
    int? currentSegmentIndex,
    List<Map<String, dynamic>>? recentSplits,
    int? kmDurationS,
    int? kmAvgBpm,
  }) async {
    if (state.runId == null) {
      // ignore: avoid_print
      print('coach.cue.skip event=$event reason=no_run_id');
      return;
    }
    // Janela da saudação: não deixa nenhum cue tocar por cima da saudação
    // inicial (finish é exceção — nunca cai aqui no início de qualquer forma).
    if (event != 'finish' &&
        DateTime.now().millisecondsSinceEpoch < _suppressCuesUntilMs) {
      // ignore: avoid_print
      print('coach.cue.skip event=$event reason=greeting_window');
      return;
    }
    if (_coachRequestInFlight) {
      final blockedAge = _coachRequestStartedAt == null
          ? '?'
          : '${DateTime.now().millisecondsSinceEpoch - _coachRequestStartedAt!}ms';
      // ignore: avoid_print
      print('coach.cue.skip event=$event reason=in_flight inFlightFor=$blockedAge');
      return;
    }

    // ignore: avoid_print
    print('coach.cue.fire event=$event km=$kmReached distanceM=${distanceM ?? state.distanceM}');
    _coachRequestInFlight = true;
    _coachRequestStartedAt = DateTime.now().millisecondsSinceEpoch;
    // Safety net curto (15s): se await for não terminar por algum motivo
    // bizarro, finally cobre tudo. Mas mantemos pra garantir que mesmo
    // se Future fica pendurada o flag libera.
    Timer(const Duration(seconds: 15), () {
      if (_coachRequestInFlight &&
          _coachRequestStartedAt != null &&
          DateTime.now().millisecondsSinceEpoch - _coachRequestStartedAt! >= 15000) {
        // ignore: avoid_print
        print('coach.cue.safety_release event=$event');
        _coachRequestInFlight = false;
        _coachRequestStartedAt = null;
      }
    });

    try {
      // await for + try/finally: substituiu .listen(onError/onDone).
      // O bug que segurava o flag: stream Dio com response 204 podia
      // não disparar onDone() em tempo confiável (especialmente web,
      // SSE encerrado por server-side res.end() sem chunk). Agora o
      // flag SEMPRE libera no finally, independente de como o stream
      // termina (chunks, vazio, erro).
      await for (final cue in _coachRemote.streamCoachCue(
        runId: state.runId!,
        event: event,
        runType: state.runType,
        currentPaceMinKm: currentPaceMinKm ?? _computePaceMinKm(),
        targetPaceMinKm: targetPaceMinKm ?? _parsePaceMinKm(state.targetPace),
        targetDistance: state.targetDistance,
        distanceM: distanceM ?? state.distanceM,
        elapsedS: elapsedS ?? state.elapsedS,
        kmReached: kmReached,
        kmDurationS: kmDurationS,
        kmAvgBpm: kmAvgBpm,
        // Sempre passa planSessionId/currentSegmentIndex quando
        // disponíveis. Server resolve briefing completo só pra eventos
        // estruturais (start/finish/segment_*/pace_alert); ruído
        // (km_reached/motivation) já economiza via sessionSummary.
        planSessionId: _planSessionId,
        currentSegmentIndex: currentSegmentIndex ??
            (_currentSegmentIdx >= 0 ? _currentSegmentIdx : null),
        recentSplits: recentSplits,
      )) {
        // ignore: avoid_print
        print('coach.cue.chunk event=$event textLen=${cue.text.length} hasAudio=${(cue.audioBase64 ?? '').isNotEmpty}');
        if (isClosed) return;
        add(_CoachChunk(cue));
      }
    } catch (err) {
      // ignore: avoid_print
      print('coach.cue.error event=$event err=$err');
    } finally {
      _coachRequestInFlight = false;
      _coachRequestStartedAt = null;
      // ignore: avoid_print
      print('coach.cue.done event=$event');
    }
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
