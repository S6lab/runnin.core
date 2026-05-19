import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class BenchmarkResult {
  final List<BenchmarkRow> items;
  final num percentileTop;
  final int cohortSize;

  const BenchmarkResult({
    required this.items,
    required this.percentileTop,
    required this.cohortSize,
  });
}

class BenchmarkRemoteDatasource {
  final Dio _dio;
  BenchmarkRemoteDatasource() : _dio = apiClient;

  Future<BenchmarkResult> getBenchmark(String runId) async {
    final res = await _dio.get('/benchmark/$runId');
    final data = res.data as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => BenchmarkRow(
              label: e['label'] as String,
              userValue: e['userValue'] as String,
              cohortValue: e['cohortValue'] as String,
              betterIsLower: e['betterIsLower'] as bool,
            ))
        .toList();
    return BenchmarkResult(
      items: items,
      percentileTop: (data['percentileTop'] as num?) ?? 0,
      cohortSize: (data['cohortSize'] as num?)?.toInt() ?? 0,
    );
  }
}
