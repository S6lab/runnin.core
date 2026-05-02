import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

class PlanRemoteDatasource {
  final Dio _dio;
  PlanRemoteDatasource() : _dio = apiClient;

  Future<Plan?> getCurrentPlan() async {
    try {
      final res = await _dio.get('/plans/current');
      return Plan.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> generatePlan({
    required String goal,
    required String level,
    int? frequency,
    int? weeksCount,
  }) async {
    final res = await _dio.post(
      '/plans/generate',
      data: {
        'goal': goal,
        'level': level,
        'weeksCount': ?weeksCount,
        'frequency': ?frequency,
      },
    );
    return (res.data as Map<String, dynamic>)['planId'] as String;
  }

  Future<Plan> getPlanById(String planId) async {
    final res = await _dio.get('/plans/$planId');
    return Plan.fromJson(res.data as Map<String, dynamic>);
  }
}
