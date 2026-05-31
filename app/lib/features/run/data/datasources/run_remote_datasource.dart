import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';

class RunRemoteDatasource {
  final Dio _dio;
  RunRemoteDatasource() : _dio = apiClient;

  Future<Run> createRun({
    required String type,
    String? targetPace,
    String? targetDistance,
    String? planSessionId,
  }) async {
    final res = await _dio.post(
      '/runs',
      data: {
        'type': type,
        'targetPace': ?targetPace,
        'targetDistance': ?targetDistance,
        'planSessionId': ?planSessionId,
      },
    );
    return Run.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> addGpsBatch(String runId, List<GpsPoint> points) async {
    if (points.isEmpty) return;
    await _dio.patch(
      '/runs/$runId/gps',
      data: {'points': points.map((p) => p.toJson()).toList()},
    );
  }

  Future<Run> completeRun(
    String runId, {
    required double distanceM,
    required int durationS,
    int? avgBpm,
    int? maxBpm,
    List<KmSplit>? splits,
  }) async {
    final res = await _dio.patch(
      '/runs/$runId/complete',
      data: {
        'distanceM': distanceM,
        'durationS': durationS,
        'avgBpm': ?avgBpm,
        'maxBpm': ?maxBpm,
        if (splits != null && splits.isNotEmpty)
          'splits': splits.map((s) => s.toCompletePayload()).toList(),
      },
    );
    return Run.fromJson(res.data as Map<String, dynamic>);
  }

  /// Submete o feedback subjetivo do user pós-corrida (chips + note opcional).
  /// Idempotente: re-submissão sobrescreve. Server agrega o feedback das runs
  /// da semana no cron de domingo pra propor revisão do plano.
  Future<Run> submitFeedback(String runId, List<CheckpointInput> inputs) async {
    final res = await _dio.patch(
      '/runs/$runId/feedback',
      data: {'inputs': inputs.map((e) => e.toJson()).toList()},
    );
    return Run.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Run> getRun(String runId) async {
    final res = await _dio.get('/runs/$runId');
    return Run.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<GpsPoint>> getGpsPoints(String runId) async {
    try {
      final res = await _dio.get('/runs/$runId/gps');
      final raw = (res.data as Map<String, dynamic>)['points'] as List? ?? [];
      return raw
          .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<List<Run>> listRuns({int limit = 20}) async {
    try {
      final res = await _dio.get('/runs', queryParameters: {'limit': limit});
      final data = res.data as Map<String, dynamic>;
      return (data['runs'] as List)
          .map((r) => Run.fromJson(r as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return const [];
      rethrow;
    }
  }
}
