import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/training/domain/entities/plan_revision.dart';

class PlanRevisionResponse {
  final PlanRevision revision;
  final Plan updatedPlan;

  const PlanRevisionResponse({
    required this.revision,
    required this.updatedPlan,
  });

  factory PlanRevisionResponse.fromJson(Map<String, dynamic> j) =>
      PlanRevisionResponse(
        revision:
            PlanRevision.fromJson(j['revision'] as Map<String, dynamic>),
        updatedPlan: Plan.fromJson(j['updatedPlan'] as Map<String, dynamic>),
      );
}

class QuotaInfo {
  final int usedThisWeek;
  final int max;
  final String? resetAt;

  const QuotaInfo({
    required this.usedThisWeek,
    required this.max,
    this.resetAt,
  });
}

class PlanRevisionRemoteDatasource {
  final Dio _dio;
  PlanRevisionRemoteDatasource() : _dio = apiClient;

  Future<PlanRevisionResponse> requestRevision(
    String planId, {
    required String type,
    String? subOption,
    String? freeText,
  }) async {
    final res = await _dio.post(
      '/plans/$planId/request-revision',
      data: {
        'type': type,
        'subOption': ?subOption,
        'freeText': ?freeText,
      },
    );
    // Revisão mudou o plano — invalida o cache.
    PlanRemoteDatasource.clearPlanCache();
    return PlanRevisionResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<PlanRevision>> listRevisions(String planId) async {
    final res = await _dio.get('/plans/$planId/revisions');
    final list = res.data as List;
    return list
        .map((item) => PlanRevision.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Detalhe de uma revisão do histórico (aplicada pelo cron ou manual) —
  /// inclui os snapshots old/new das semanas e a explicação do coach.
  Future<PlanRevision> getRevision(String planId, String revisionId) async {
    final res = await _dio.get('/plans/$planId/revisions/$revisionId');
    return PlanRevision.fromJson(res.data as Map<String, dynamic>);
  }
}
