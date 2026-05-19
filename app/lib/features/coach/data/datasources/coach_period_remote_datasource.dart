import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

class CoachPeriodRemoteDatasource {
  final Dio _dio;
  CoachPeriodRemoteDatasource() : _dio = apiClient;

  Future<Map<String, dynamic>> getPeriodAnalysis({
    required String startDate,
    required String endDate,
  }) async {
    final res = await _dio.get(
      '/coach/period-analysis',
      queryParameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return res.data as Map<String, dynamic>;
  }
}
