import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/training/domain/entities/weekly_report.dart';

class WeeklyReportRemoteDatasource {
  final Dio _dio;
  WeeklyReportRemoteDatasource() : _dio = apiClient;

  Future<List<WeeklyReport>> getWeeklyReports() async {
    try {
      final res = await _dio.get('/weekly-reports');
      final data = res.data as List;
      return data.map((e) => WeeklyReport.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) return [];
      rethrow;
    }
  }

  Future<WeeklyReport?> getWeeklyReportByWeekStart(String weekStart) async {
    try {
      final res = await _dio.get('/weekly-reports/$weekStart');
      return WeeklyReport.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 404) return null;
      rethrow;
    }
  }
}
