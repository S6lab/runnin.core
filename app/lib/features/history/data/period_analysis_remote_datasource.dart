import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/history/domain/entities/period_analysis.dart';

class PeriodAnalysisRemoteDatasource {
  final Dio _dio;
  PeriodAnalysisRemoteDatasource() : _dio = apiClient;

  Future<PeriodAnalysis> getPeriodAnalysis(int limit) async {
    final res = await _dio.get('/coach/period-analysis?limit=$limit');
    return PeriodAnalysis.fromJson(res.data as Map<String, dynamic>);
  }
}
