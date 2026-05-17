import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_local_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/data/live_coach_voice_service.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

// ── Events ──────────────────────────────────────────────────────────────────
abstract class RunEvent {}

class StartRun extends RunEvent {
  final String type;
  final String? targetPace;
  final String? targetDistance;
  StartRun({required this.type, this.targetPace, this.targetDistance});
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

// ── State ────────────────────────────────────────────────────────────────────
enum RunStatus { idle, starting, active, completing, completed, error }

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

  StreamSubscription<Position>? _gpsSub;
  Timer? _timer;
  Timer? _flushTimer;
  int _pendingFlushCount = 0;
  bool _coachRequestInFlight = false;
  int _lastCoachKm = 0;

  static const _accuracyThreshold = 15.0; // metros
  static const _displayAccuracyThreshold = 150.0; // metros
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
    _local.init();
  }

  Future<void> _onStart(StartRun event, Emitter<RunState> emit) async {
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
      // Saudação inicial via Gemini Live DIRETO (sem /coach/message).
      // App fala com Live → recebe áudio WAV → toca. Sem proxy, sem TTS
      // estático, sem 504 no Cloud Run. Roda em background.
      unawaited(_speakStartGreeting(event.type));

      // Timer de tempo decorrido
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => add(_TimerTick()),
      );

      // Stream de GPS
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // só atualiza se moveu > 5m
        ),
      ).listen((pos) => add(_GpsUpdate(pos)));

      Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          )
          .then((pos) {
            if (!isClosed) add(_GpsUpdate(pos));
          })
          .catchError((_) {});

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
    emit(
      state.copyWith(
        coachLiveMessage: event.cue.text,
        coachAudioBase64: event.cue.audioBase64 ?? '',
        coachAudioMimeType: event.cue.audioMimeType ?? '',
      ),
    );
  }

  void _onGpsUpdate(_GpsUpdate event, Emitter<RunState> emit) {
    if (state.status != RunStatus.active) return;

    final pos = event.pos;

    // Filtra ruído extremo, mas mantém precisão moderada para mostrar o mapa no web.
    if (pos.accuracy > _displayAccuracyThreshold) return;

    final newPoint = GpsPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      ts: pos.timestamp.millisecondsSinceEpoch,
      accuracy: pos.accuracy,
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

    emit(
      state.copyWith(
        points: newPoints,
        distanceM: newDistance,
        currentPaceMinKm: smoothedPace,
      ),
    );

    final kmReached = (newDistance / 1000).floor();
    if (kmReached > _lastCoachKm && kmReached > 0) {
      _lastCoachKm = kmReached;
      _requestCoachCue(
        event: 'km_reached',
        kmReached: kmReached,
        distanceM: newDistance,
        elapsedS: state.elapsedS,
        currentPaceMinKm: smoothedPace,
      );
    }

    // Pace alert trigger: when pace deviates from target by ±10%
    if (smoothedPace != null &&
        state.targetPace != null &&
        state.status == RunStatus.active) {
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
        }
      }
    }

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

  void _stop() {
    _gpsSub?.cancel();
    _timer?.cancel();
    _flushTimer?.cancel();
    _gpsSub = null;
    _timer = null;
    _flushTimer = null;
    _coachRequestInFlight = false;
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
      final profile = await _userRemote.getMe().timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
      final fullName = profile?.name.trim() ?? '';
      final firstName = fullName.isEmpty
          ? null
          : fullName.split(RegExp(r'\s+')).first;
      final typeNice = runType.toLowerCase().replaceFirst('free run', 'corrida livre');
      final greeting = firstName != null && firstName.isNotEmpty
          ? 'Bora $firstName! Começando a $typeNice. Vou te acompanhar.'
          : 'Bora! Começando a $typeNice. Vou te acompanhar.';

      final audio = await _liveVoice.synthesize(
        greeting,
        voiceId: profile?.coachVoiceId,
      );
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

  void _requestCoachCue({
    required String event,
    int? kmReached,
    double? distanceM,
    int? elapsedS,
    double? currentPaceMinKm,
    double? targetPaceMinKm,
  }) {
    if (state.runId == null || _coachRequestInFlight) return;

    _coachRequestInFlight = true;
    _coachRemote
        .streamCoachCue(
          runId: state.runId!,
          event: event,
          runType: state.runType,
          currentPaceMinKm: currentPaceMinKm ?? _computePaceMinKm(),
          targetPaceMinKm: targetPaceMinKm ?? _parsePaceMinKm(state.targetPace),
          targetDistance: state.targetDistance,
          distanceM: distanceM ?? state.distanceM,
          elapsedS: elapsedS ?? state.elapsedS,
          kmReached: kmReached,
        )
        .listen(
          (cue) {
            if (isClosed) return;
            add(_CoachChunk(cue));
          },
          onError: (_) {
            _coachRequestInFlight = false;
          },
          onDone: () {
            _coachRequestInFlight = false;
          },
        );
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
