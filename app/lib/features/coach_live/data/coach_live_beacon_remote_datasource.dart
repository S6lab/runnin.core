import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/coach_live/data/coach_context_manager.dart';

/// Wrapper Dio fire-and-forget pra POST /coach/live-turn. Server persiste
/// em users/{uid}/runs/{runId}/coach_messages — necessário porque a app
/// conecta direto no Gemini Live e o conteúdo dos turnos NÃO passa pelo
/// nosso server (só os beacons de diag).
///
/// Sem await em path crítico do RunBloc: falha aqui não afeta a corrida.
class CoachLiveBeaconRemoteDatasource {
  CoachLiveBeaconRemoteDatasource({Dio? dio}) : _dio = dio ?? apiClient;

  final Dio _dio;

  Future<void> logCoachTurn({
    required String runId,
    required String text,
    required String trigger,
    required int sessionGeneration,
    RunMetricsSnapshot? metrics,
  }) async {
    await _post(
      runId: runId,
      author: 'coach',
      text: text,
      trigger: trigger,
      sessionGeneration: sessionGeneration,
      metrics: metrics,
    );
  }

  Future<void> _post({
    required String runId,
    required String author,
    required String text,
    required String trigger,
    required int sessionGeneration,
    RunMetricsSnapshot? metrics,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty || runId.isEmpty) return;
    final serverEvent = trigger;
    final body = <String, dynamic>{
      'runId': runId,
      'author': author,
      'text': clean,
      if (_isServerAllowedEvent(serverEvent)) 'event': serverEvent,
      'sessionGeneration': sessionGeneration,
      if (metrics?.distanceKm != null) 'kmAtTime': metrics!.distanceKm,
      if (metrics?.paceAtTimeStr != null) 'paceAtTime': metrics!.paceAtTimeStr,
      if (metrics?.avgBpm != null) 'bpmAtTime': metrics!.avgBpm,
    };
    try {
      await _dio.post<void>(
        '/coach/live-turn',
        data: body,
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
    } catch (_) {
      // best-effort: persistência server-side é replay/auditoria, sem ela
      // a corrida continua normalmente.
    }
  }

  // Os 8 eventos canônicos da migração s6-ai (LiveTurnSchema do server).
  static const _serverEventAllowlist = <String>{
    'start',
    'half_km',
    'km_reached',
    'bpm_alert',
    'pace_alert',
    'goal_reached',
    'finish',
    'no_movement',
  };

  static bool _isServerAllowedEvent(String e) =>
      _serverEventAllowlist.contains(e);
}
