import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/coach/domain/entities/coach_report.dart';

class CoachReportRemoteDatasource {
  final Dio _dio;
  CoachReportRemoteDatasource() : _dio = apiClient;

  Future<CoachReport> getReport(String runId) async {
    final res = await _dio.get('/coach/report/$runId');
    return CoachReport.fromJson(res.data as Map<String, dynamic>);
  }
}
