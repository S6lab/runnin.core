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

  /// Aplica o ajuste: roda LLM, gera PlanRevision, ajusta semanas seguintes
  /// do plano. Cobrado pelo gate premium no server (403 PREMIUM_REQUIRED se
  /// freemium tentar).
  Future<CheckpointApplyResult> apply(
    String planId,
    int weekNumber,
    List<CheckpointInput> extraInputs,
  ) async {
    final res = await _dio.post(
      '/plans/$planId/checkpoints/$weekNumber/apply',
      data: {'inputs': extraInputs.map((e) => e.toJson()).toList()},
    );
    final body = res.data as Map<String, dynamic>;
    return CheckpointApplyResult(
      checkpoint: PlanCheckpoint.fromJson(body['checkpoint'] as Map<String, dynamic>),
      revisionId: (body['revision'] as Map<String, dynamic>?)?['id'] as String?,
      coachExplanation:
          (body['revision'] as Map<String, dynamic>?)?['coachExplanation'] as String?,
    );
  }
}

class CheckpointApplyResult {
  final PlanCheckpoint checkpoint;
  final String? revisionId;
  final String? coachExplanation;
  const CheckpointApplyResult({
    required this.checkpoint,
    this.revisionId,
    this.coachExplanation,
  });
}
