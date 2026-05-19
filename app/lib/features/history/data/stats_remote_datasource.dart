import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';

class StatsRemoteDatasource {
  final Dio _dio;
  StatsRemoteDatasource() : _dio = apiClient;

  /// period: 'week' | 'month' | 'threeMonths'
  Future<StatsAggregate> getAggregate(String period) async {
    final res = await _dio.get('/stats/aggregate', queryParameters: {'period': period});
    return StatsAggregate.fromJson(res.data as Map<String, dynamic>);
  }
}
