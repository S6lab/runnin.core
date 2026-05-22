import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/plan_checkpoint.dart';

/// Datasource desacoplado: troca via construtor pra testes / mocks.
class CheckpointRemoteDatasource {
  final Dio _dio;
  CheckpointRemoteDatasource({Dio? dio}) : _dio = dio ?? apiClient;

  Future<List<PlanCheckpoint>> listForPlan(String planId) async {
    try {
      final res = await _dio.get('/plans/$planId/checkpoints');
      final items = (res.data as Map<String, dynamic>)['items'] as List? ?? [];
      return items
          .map((e) => PlanCheckpoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<PlanCheckpoint?> getOne(String planId, int weekNumber) async {
    try {
      final res = await _dio.get('/plans/$planId/checkpoints/$weekNumber');
      return PlanCheckpoint.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Persiste inputs sem aplicar — útil pra rascunho.
  Future<PlanCheckpoint> submitInputs(
    String planId,
    int weekNumber,
    List<CheckpointInput> inputs,
  ) async {
    final res = await _dio.post(
      '/plans/$planId/checkpoints/$weekNumber/inputs',
      data: {'inputs': inputs.map((e) => e.toJson()).toList()},
    );
    return PlanCheckpoint.fromJson(res.data as Map<String, dynamic>);
  }

  /// "Depois": adia o checkpoint sem ajuste (marca skipped). As semanas
  /// pendentes são detalhadas na revisão de domingo.
  Future<PlanCheckpoint> skip(String planId, int weekNumber) async {
    final res = await _dio.post('/plans/$planId/checkpoints/$weekNumber/skip');
    return PlanCheckpoint.fromJson(res.data as Map<String, dynamic>);
  }
}
