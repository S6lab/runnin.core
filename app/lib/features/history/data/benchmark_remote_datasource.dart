import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class BenchmarkRemoteDatasource {
  final Dio _dio;
  BenchmarkRemoteDatasource() : _dio = apiClient;

  Future<List<BenchmarkRow>> getBenchmark(String runId) async {
    final res = await _dio.get('/benchmark/$runId');
    final data = res.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    return items
        .map((e) => BenchmarkRow(
          label: e['label'] as String,
          userValue: e['userValue'] as String,
          cohortValue: e['cohortValue'] as String,
          betterIsLower: e['betterIsLower'] as bool,
        ))
        .toList();
  }
}
