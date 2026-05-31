import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/history/domain/entities/stats_aggregate.dart';
import 'package:runnin/features/history/domain/entities/stats_breakdown.dart';

/// Remote datasource for history stats.
/// Calls /v1/stats/aggregate (deltas) and /v1/stats/breakdown (DADOS:
/// stats consolidados + séries planejado-vs-realizado de volume e pace).
class StatsRemoteDatasource {
  final Dio _dio;
  StatsRemoteDatasource() : _dio = apiClient;

  /// period: 'week' | 'month' | 'threeMonths'
  Future<StatsAggregate> getAggregate(String period) async {
    final res = await _dio.get('/stats/aggregate', queryParameters: {'period': period});
    return StatsAggregate.fromJson(res.data as Map<String, dynamic>);
  }

  /// Stats consolidados (11 métricas) + buckets de volume/pace por período.
  Future<StatsBreakdown> getBreakdown(String period) async {
    final res = await _dio.get('/stats/breakdown', queryParameters: {'period': period});
    return StatsBreakdown.fromJson(res.data as Map<String, dynamic>);
  }
}
