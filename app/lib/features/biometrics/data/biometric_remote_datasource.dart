import 'package:dio/dio.dart';
import 'package:runnin/core/network/api_client.dart';

/// Espelha o payload do server `POST /v1/biometrics/samples`.
class BiometricSampleInput {
  final String type;
  final num value;
  final String unit;
  final String source;
  final String recordedAt;
  final Map<String, dynamic>? context;

  const BiometricSampleInput({
    required this.type,
    required this.value,
    required this.unit,
    required this.source,
    required this.recordedAt,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'unit': unit,
        'source': source,
        'recordedAt': recordedAt,
        if (context != null) 'context': context,
      };
}

class BiometricSummary {
  final int windowDays;
  final num? avgRestingBpm;
  final num? maxBpm;
  final num? avgSleepHours;
  final num? totalSteps;
  final num? avgHrv;
  final num? latestWeight;
  final int sampleCount;

  const BiometricSummary({
    required this.windowDays,
    this.avgRestingBpm,
    this.maxBpm,
    this.avgSleepHours,
    this.totalSteps,
    this.avgHrv,
    this.latestWeight,
    required this.sampleCount,
  });

  factory BiometricSummary.fromJson(Map<String, dynamic> j) => BiometricSummary(
        windowDays: j['windowDays'] as int? ?? 7,
        avgRestingBpm: j['avgRestingBpm'] as num?,
        maxBpm: j['maxBpm'] as num?,
        avgSleepHours: j['avgSleepHours'] as num?,
        totalSteps: j['totalSteps'] as num?,
        avgHrv: j['avgHrv'] as num?,
        latestWeight: j['latestWeight'] as num?,
        sampleCount: j['sampleCount'] as int? ?? 0,
      );
}

class BiometricRemoteDatasource {
  final Dio _dio;
  BiometricRemoteDatasource() : _dio = apiClient;

  Future<({int received, int saved})> ingest(List<BiometricSampleInput> samples) async {
    if (samples.isEmpty) return (received: 0, saved: 0);
    final res = await _dio.post(
      '/biometrics/samples',
      data: {'samples': samples.map((s) => s.toJson()).toList()},
    );
    final data = res.data as Map<String, dynamic>;
    return (
      received: (data['received'] as num?)?.toInt() ?? 0,
      saved: (data['saved'] as num?)?.toInt() ?? 0,
    );
  }

  Future<BiometricSummary> getSummary({int windowDays = 7}) async {
    final res = await _dio.get(
      '/biometrics/summary',
      queryParameters: {'windowDays': windowDays},
    );
    return BiometricSummary.fromJson(res.data as Map<String, dynamic>);
  }
}
